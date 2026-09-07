package com.mobili.backend.module.trip.service;

import com.mobili.backend.module.routing.dto.DirectionsRequest;
import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.service.DirectionsOrchestratorService;
import com.mobili.backend.module.trip.dto.TripEtaResponse;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStatus;
import com.mobili.backend.module.trip.entity.TripStop;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Calcule le temps restant vers le prochain arrêt d'un trajet EN_COURS — appelé à la demande par
 * l'app passager (toutes les 5 min pendant qu'un écran de suivi est ouvert), jamais par un
 * scheduler backend (voir DirectionsOrchestratorService pour l'arbitrage). Un cache court par
 * tripId amortit le cas de plusieurs passagers du même trajet ouvrant l'écran en même temps,
 * sans complexité de scheduling.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class TripEtaService {

    /** 60-90s : largement sous la fréquence d'appel client (5 min), sert uniquement à amortir
     *  plusieurs passagers du même trajet interrogeant l'endpoint à quelques secondes d'écart. */
    private static final Duration CACHE_TTL = Duration.ofSeconds(75);

    private final TripService tripService;
    private final TripRunService tripRunService;
    private final DirectionsOrchestratorService directionsOrchestratorService;

    private record CachedEta(TripEtaResponse response, Instant computedAt) {
        boolean isExpired() {
            return Duration.between(computedAt, Instant.now()).compareTo(CACHE_TTL) > 0;
        }
    }

    private final Map<Long, CachedEta> cache = new ConcurrentHashMap<>();

    public TripEtaResponse getEta(Long tripId, double originLat, double originLng) {
        Trip trip = tripService.findById(tripId);
        if (trip.getStatus() != TripStatus.EN_COURS) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Ce trajet n'est pas en cours — pas de calcul d'ETA possible.");
        }

        CachedEta cached = cache.get(tripId);
        if (cached != null && !cached.isExpired()) {
            return cached.response();
        }

        TripStop nextStop = tripRunService.nextStopOrNull(trip);
        TripEtaResponse response;
        if (nextStop == null || nextStop.getLatitude() == null || nextStop.getLongitude() == null) {
            log.warn("⚠️ ETA indisponible pour Trip #{} — prochain arrêt sans coordonnées renseignées.", tripId);
            response = TripEtaResponse.unavailable(nextStop != null ? nextStop.getCityLabel() : null);
        } else {
            DirectionsRequest request = new DirectionsRequest(
                    originLat, originLng, nextStop.getLatitude(), nextStop.getLongitude());
            DirectionsResult result = directionsOrchestratorService.getDirectionsWithFallback(request);
            response = TripEtaResponse.available(nextStop.getCityLabel(), result);
        }

        cache.put(tripId, new CachedEta(response, Instant.now()));
        return response;
    }
}
