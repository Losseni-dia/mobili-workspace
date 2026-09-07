package com.mobili.backend.module.routing.mapbox.service;

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
import java.util.Locale;
import java.util.Map;

/**
 * Fournisseur PRINCIPAL de la passerelle directions (voir DirectionsOrchestratorService pour la
 * bascule vers Google Maps). Appelle Mapbox Directions API — voir
 * https://docs.mapbox.com/api/navigation/directions/.
 */
@Service
@Slf4j
public class MapboxDirectionsService implements DirectionsProviderService {

    private final RestClient restClient;

    @Value("${mapbox.access-token}")
    private String accessToken;

    public MapboxDirectionsService(RestClient.Builder restClientBuilder) {
        this.restClient = restClientBuilder
                .baseUrl("https://api.mapbox.com/directions/v5/mapbox/driving")
                .build();
    }

    @Override
    public DirectionsResult getDirections(DirectionsRequest request) {
        log.info("🚀 Requête Mapbox Directions ({}, {}) -> ({}, {})",
                request.originLat(), request.originLng(), request.destinationLat(), request.destinationLng());

        // Mapbox attend "lng,lat;lng,lat" (longitude en premier, contre-intuitif) dans le chemin.
        String coordinates = String.format(Locale.ROOT, "%f,%f;%f,%f",
                request.originLng(), request.originLat(), request.destinationLng(), request.destinationLat());

        Map<String, Object> body = restClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/{coordinates}")
                        .queryParam("access_token", accessToken)
                        .queryParam("overview", "false")
                        .queryParam("alternatives", "false")
                        .build(coordinates))
                .retrieve()
                .body(Map.class);

        if (body == null) {
            log.error("❌ Réponse Mapbox vide pour ({}, {}) -> ({}, {})",
                    request.originLat(), request.originLng(), request.destinationLat(), request.destinationLng());
            throw new IllegalStateException("Réponse Mapbox Directions vide.");
        }

        // Code "NoRoute" (ou "NoSegment") : Mapbox répond 200 avec ce code dans le corps, pas un
        // statut HTTP d'erreur — voir doc Mapbox "Directions API errors". Seul ce cas déclenche
        // NoRouteFoundException (jamais une erreur réseau/HTTP générique, qui remonte telle
        // quelle via RestClientException, sans transformation).
        String code = (String) body.get("code");
        if (!"Ok".equals(code)) {
            log.warn("⚠️ Mapbox n'a trouvé aucun itinéraire (code={}) pour ({}, {}) -> ({}, {})",
                    code, request.originLat(), request.originLng(), request.destinationLat(), request.destinationLng());
            throw new NoRouteFoundException("Mapbox : aucun itinéraire trouvé (code=" + code + ")");
        }

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> routes = (List<Map<String, Object>>) body.get("routes");
        if (routes == null || routes.isEmpty()) {
            log.warn("⚠️ Mapbox : code Ok mais aucune route dans la réponse — traité comme NoRoute.");
            throw new NoRouteFoundException("Mapbox : aucune route dans une réponse pourtant Ok.");
        }

        Map<String, Object> firstRoute = routes.get(0);
        long durationSeconds = Math.round(((Number) firstRoute.get("duration")).doubleValue());
        double distanceMeters = ((Number) firstRoute.get("distance")).doubleValue();

        log.info("✅ Itinéraire Mapbox trouvé : {}s, {}m", durationSeconds, distanceMeters);
        return new DirectionsResult(durationSeconds, distanceMeters, DirectionsProvider.MAPBOX);
    }

    @Override
    public DirectionsProvider getDirectionsProvider() {
        return DirectionsProvider.MAPBOX;
    }
}
