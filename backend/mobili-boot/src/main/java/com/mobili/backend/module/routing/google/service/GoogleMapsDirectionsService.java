package com.mobili.backend.module.routing.google.service;

import com.mobili.backend.module.routing.dto.DirectionsRequest;
import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.enums.DirectionsProvider;
import com.mobili.backend.module.routing.exception.NoRouteFoundException;
import com.mobili.backend.module.routing.service.DirectionsProviderService;

import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

/**
 * Fournisseur de SECOURS de la passerelle directions — appelé uniquement quand Mapbox répond
 * NoRoute (voir DirectionsOrchestratorService, seul endroit qui décide de la bascule). Appelle
 * Google Maps Directions API — voir
 * https://developers.google.com/maps/documentation/directions/get-directions.
 */
@Service
@Slf4j
public class GoogleMapsDirectionsService implements DirectionsProviderService {

    private final RestClient restClient;

    @Value("${google.maps.api-key}")
    private String apiKey;

    public GoogleMapsDirectionsService(RestClient.Builder restClientBuilder) {
        this.restClient = restClientBuilder
                .baseUrl("https://maps.googleapis.com/maps/api/directions/json")
                .build();
    }

    @Override
    public DirectionsResult getDirections(DirectionsRequest request) {
        log.info("🚀 Requête Google Maps Directions ({}, {}) -> ({}, {})",
                request.originLat(), request.originLng(), request.destinationLat(), request.destinationLng());

        String origin = request.originLat() + "," + request.originLng();
        String destination = request.destinationLat() + "," + request.destinationLng();

        Map<String, Object> body = restClient.get()
                .uri(uriBuilder -> uriBuilder
                        .queryParam("origin", origin)
                        .queryParam("destination", destination)
                        .queryParam("key", apiKey)
                        .build())
                .retrieve()
                .body(Map.class);

        if (body == null) {
            log.error("❌ Réponse Google Maps vide pour ({}, {}) -> ({}, {})",
                    request.originLat(), request.originLng(), request.destinationLat(), request.destinationLng());
            throw new IllegalStateException("Réponse Google Maps Directions vide.");
        }

        // "ZERO_RESULTS" : Google répond HTTP 200 avec ce statut métier quand aucun itinéraire
        // n'existe — voir doc "Directions API status codes". Seul ce statut (et l'absence de
        // routes malgré un statut OK) est traité comme NoRouteFoundException ; tout autre statut
        // (INVALID_REQUEST, OVER_QUERY_LIMIT, REQUEST_DENIED...) est une vraie erreur technique,
        // remontée telle quelle — pas un "aucun itinéraire" au sens métier.
        String status = (String) body.get("status");
        if ("ZERO_RESULTS".equals(status)) {
            log.warn("⚠️ Google Maps n'a trouvé aucun itinéraire (status=ZERO_RESULTS) pour ({}, {}) -> ({}, {})",
                    request.originLat(), request.originLng(), request.destinationLat(), request.destinationLng());
            throw new NoRouteFoundException("Google Maps : aucun itinéraire trouvé (status=ZERO_RESULTS)");
        }
        if (!"OK".equals(status)) {
            log.error("❌ Google Maps Directions a échoué (status={}) pour ({}, {}) -> ({}, {})",
                    status, request.originLat(), request.originLng(), request.destinationLat(), request.destinationLng());
            throw new IllegalStateException("Google Maps Directions : statut inattendu " + status);
        }

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> routes = (List<Map<String, Object>>) body.get("routes");
        if (routes == null || routes.isEmpty()) {
            log.warn("⚠️ Google Maps : statut OK mais aucune route dans la réponse — traité comme NoRoute.");
            throw new NoRouteFoundException("Google Maps : aucune route dans une réponse pourtant OK.");
        }

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> legs = (List<Map<String, Object>>) routes.get(0).get("legs");
        Map<String, Object> firstLeg = legs.get(0);
        @SuppressWarnings("unchecked")
        long durationSeconds = ((Number) ((Map<String, Object>) firstLeg.get("duration")).get("value")).longValue();
        @SuppressWarnings("unchecked")
        double distanceMeters = ((Number) ((Map<String, Object>) firstLeg.get("distance")).get("value")).doubleValue();

        log.info("✅ Itinéraire Google Maps trouvé : {}s, {}m", durationSeconds, distanceMeters);
        return new DirectionsResult(durationSeconds, distanceMeters, DirectionsProvider.GOOGLE_MAPS);
    }

    @Override
    public DirectionsProvider getDirectionsProvider() {
        return DirectionsProvider.GOOGLE_MAPS;
    }
}
