package com.mobili.backend.module.trip.service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.routing.dto.DirectionsRequest;
import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.entity.CityLegDuration;
import com.mobili.backend.module.routing.repository.CityLegDurationRepository;
import com.mobili.backend.module.routing.service.DirectionsOrchestratorService;
import com.mobili.backend.module.city.repository.CityRepository;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStop;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Reconstruit la liste ordonnée des arrêts (villes) et les horaires planifiés de départ par arrêt.
 * Overload texte ({@link #syncStopsForTrip(Trip)}) : pas de GPS, forfait {@link #PLANNED_LEG_MINUTES}
 * par tronçon. Overload résolu ({@link #syncStopsForTrip(Trip, List)}) : durée réelle
 * (DirectionsOrchestratorService) quand les deux extrémités du tronçon ont des coordonnées
 * connues, même repli forfaitaire sinon (ville pas encore géocodée par un admin).
 *
 * <p>La durée réelle d'une paire de villes est mise en cache ({@link CityLegDuration}) : sans ce
 * cache, chaque enregistrement d'un trajet de N arrêts facturerait jusqu'à N-1 appels Mapbox/
 * Google Directions, y compris pour un simple changement de prix ou d'horaire sur un trajet dont
 * l'itinéraire n'a pas bougé. Avec le cache, une paire de villes n'est calculée qu'une fois (puis
 * rafraîchie après {@link #STALE_AFTER}), quel que soit le nombre de trajets/éditions qui la
 * réutilisent — le coût annoncé initialement ("jusqu'à N-1 appels par enregistrement") ne
 * s'applique donc qu'à la toute première fois qu'une paire de villes est utilisée.</p>
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class TripStopSyncService {

    /** Délai entre deux arrêts consécutifs pour l’horaire planifié — forfait MVP, et repli quand
     *  une extrémité du tronçon n'a pas encore de coordonnées connues. */
    public static final int PLANNED_LEG_MINUTES = 60;

    /** Un trajet entre deux villes ne change pas d'une semaine à l'autre — 180 jours limite le
     *  nombre de rafraîchissements payants tout en gardant les données à jour sur le long terme
     *  (nouvelle route, déviation durable, etc.). */
    static final Duration STALE_AFTER = Duration.ofDays(180);

    private final DirectionsOrchestratorService directionsOrchestratorService;
    private final CityLegDurationRepository cityLegDurationRepository;
    private final CityRepository cityRepository;

    /** Un arrêt déjà résolu (ville + coordonnées si connues) — voir TripService.buildStructuredStops.
     *  {@code cityId} sert de clé de cache pour {@link CityLegDuration} (toujours renseigné pour un
     *  arrêt issu du flux structuré, y compris une ville "introuvable" nouvellement créée : elle a
     *  déjà un id dès sa création par CityLookupService). */
    public record ResolvedStop(Long cityId, String cityLabel, Double latitude, Double longitude) {
    }

    public void syncStopsForTrip(Trip trip) {
        trip.getStops().clear();
        List<String> labels = buildCityLabels(trip);
        LocalDateTime base = trip.getDepartureDateTime();
        for (int i = 0; i < labels.size(); i++) {
            TripStop stop = new TripStop();
            stop.setTrip(trip);
            stop.setStopIndex(i);
            stop.setCityLabel(labels.get(i));
            stop.setPlannedDepartureAt(base.plusMinutes((long) i * PLANNED_LEG_MINUTES));
            trip.getStops().add(stop);
        }
    }

    /**
     * Même reconstruction que {@link #syncStopsForTrip(Trip)}, mais à partir d'arrêts déjà résolus
     * vers de vraies villes (cityId/coordonnées connues) au lieu de redécouper
     * {@code trip.getMoreInfo()} sur des virgules — utilisé quand le client envoie
     * {@code TripRequestDTO.stops}/{@code departureCityId}/{@code arrivalCityId} (voir
     * TripService.save). Les coordonnées, quand présentes, alimentent le calcul de durée réelle
     * (module routing) au lieu du forfait {@link #PLANNED_LEG_MINUTES} par tronçon.
     */
    @Transactional
    public void syncStopsForTrip(Trip trip, List<ResolvedStop> resolvedStops) {
        trip.getStops().clear();
        LocalDateTime cursor = trip.getDepartureDateTime();
        for (int i = 0; i < resolvedStops.size(); i++) {
            ResolvedStop r = resolvedStops.get(i);
            if (i > 0) {
                cursor = cursor.plusMinutes(legDurationMinutes(resolvedStops.get(i - 1), r));
            }
            TripStop stop = new TripStop();
            stop.setTrip(trip);
            stop.setStopIndex(i);
            stop.setCityLabel(r.cityLabel());
            stop.setLatitude(r.latitude());
            stop.setLongitude(r.longitude());
            stop.setPlannedDepartureAt(cursor);
            trip.getStops().add(stop);
        }
    }

    /**
     * Durée réelle (arrondie à la minute) entre deux arrêts consécutifs quand les DEUX ont des
     * coordonnées connues ; repli sur {@link #PLANNED_LEG_MINUTES} sinon (ville pas encore
     * géocodée, voir écran admin Pays & Villes) ou si ni Mapbox ni Google Maps n'ont pu calculer
     * d'itinéraire — jamais un blocage de la création/modification du trajet, juste une
     * estimation dégradée pour CE tronçon (même philosophie que TripEtaService.getEta).
     */
    private long legDurationMinutes(ResolvedStop from, ResolvedStop to) {
        if (from.latitude() == null || from.longitude() == null
                || to.latitude() == null || to.longitude() == null) {
            return PLANNED_LEG_MINUTES;
        }

        if (from.cityId() != null && to.cityId() != null) {
            Optional<CityLegDuration> cached = cityLegDurationRepository
                    .findByFromCityIdAndToCityId(from.cityId(), to.cityId());
            if (cached.isPresent()
                    && Duration.between(cached.get().getComputedAt(), LocalDateTime.now()).compareTo(STALE_AFTER) < 0) {
                return Math.max(1, Math.round(cached.get().getDurationSeconds() / 60.0));
            }
        }

        try {
            DirectionsRequest request = new DirectionsRequest(
                    from.latitude(), from.longitude(), to.latitude(), to.longitude());
            DirectionsResult result = directionsOrchestratorService.getDirectionsWithFallback(request);
            if (from.cityId() != null && to.cityId() != null) {
                cacheLegDuration(from.cityId(), to.cityId(), result);
            }
            return Math.max(1, Math.round(result.durationSeconds() / 60.0));
        } catch (Exception e) {
            log.warn("⚠️ Durée réelle indisponible pour le tronçon '{}' -> '{}' ({}) — repli sur le "
                    + "forfait de {} min.", from.cityLabel(), to.cityLabel(), e.getMessage(), PLANNED_LEG_MINUTES);
            return PLANNED_LEG_MINUTES;
        }
    }

    /** Écrit/rafraîchit l'entrée de cache pour cette paire de villes — appel Directions
     *  "amorti" sur tous les trajets/éditions suivants qui réutilisent le même tronçon (voir
     *  Javadoc de la classe). Échec d'écriture non bloquant : le trajet est déjà résolu avec la
     *  bonne durée, seule la mise en cache pour les prochaines fois est perdue. */
    private void cacheLegDuration(Long fromCityId, Long toCityId, DirectionsResult result) {
        try {
            CityLegDuration entry = cityLegDurationRepository
                    .findByFromCityIdAndToCityId(fromCityId, toCityId)
                    .orElseGet(CityLegDuration::new);
            entry.setFromCity(cityRepository.getReferenceById(fromCityId));
            entry.setToCity(cityRepository.getReferenceById(toCityId));
            entry.setDurationSeconds(result.durationSeconds());
            entry.setDistanceMeters(result.distanceMeters());
            entry.setComputedAt(LocalDateTime.now());
            cityLegDurationRepository.save(entry);
        } catch (Exception e) {
            log.warn("⚠️ Échec de la mise en cache de la durée {} -> {} ({}) — sans impact sur ce trajet, "
                    + "juste un appel Directions de plus la prochaine fois.", fromCityId, toCityId, e.getMessage());
        }
    }

    /** Libellés affichage : départ, étapes CSV, arrivée (sans doublon terminal). */
    public List<String> buildCityLabels(Trip trip) {
        List<String> labels = new ArrayList<>();
        labels.add(trimCity(trip.getDepartureCity()));
        if (trip.getMoreInfo() != null && !trip.getMoreInfo().isBlank()) {
            for (String part : trip.getMoreInfo().split(",")) {
                String t = trimCity(part);
                if (!t.isEmpty() && !labels.get(labels.size() - 1).equalsIgnoreCase(t)) {
                    labels.add(t);
                }
            }
        }
        String arr = trimCity(trip.getArrivalCity());
        if (labels.isEmpty() || !labels.get(labels.size() - 1).equalsIgnoreCase(arr)) {
            labels.add(arr);
        }
        return labels;
    }

    public int lastStopIndex(Trip trip) {
        return Math.max(0, buildCityLabels(trip).size() - 1);
    }

    private static String trimCity(String raw) {
        if (raw == null) {
            return "";
        }
        String t = raw.trim();
        if (t.isEmpty()) {
            return "";
        }
        return t.substring(0, 1).toUpperCase(Locale.ROOT) + t.substring(1).toLowerCase(Locale.ROOT);
    }
}
