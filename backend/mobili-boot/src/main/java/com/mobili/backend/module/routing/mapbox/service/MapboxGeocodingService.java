package com.mobili.backend.module.routing.mapbox.service;

import com.mobili.backend.module.routing.exception.GeocodingFailedException;
import com.mobili.backend.module.routing.mapbox.dto.GeocodingResult;

import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Géocodage (nom de ville -> coordonnées) via l'API Mapbox Geocoding — voir
 * https://docs.mapbox.com/api/search/geocoding/. Distinct de MapboxDirectionsService (itinéraire
 * entre deux points déjà connus) : ici on part d'un simple nom de ville sans coordonnées.
 *
 * Utilisé UNIQUEMENT par AdminTripStopGeocodingService (écran admin de prévisualisation) —
 * jamais appelé automatiquement à la création d'un trajet (voir TripStop.java : pas de
 * géocodage à la volée, décision actée en début de chantier tracking temps réel).
 *
 * Biaise (sans exclure) les résultats vers l'Afrique de l'Ouest via `proximity` — la plupart des
 * trajets Mobili y sont, mais un vrai trajet ailleurs (ex. test Europe) reste correctement
 * géocodé : `proximity` influence juste le classement, contrairement à `country` qui exclurait
 * les autres pays. Cette recherche par nom seul reste imparfaite pour les noms courts/génériques
 * ou homonymes (observé en pratique : Tanger -> Indonésie, Gaya -> Inde, malgré ce biais) — voir
 * `ambiguous` sur GeocodingPreviewItem, à vérifier par l'admin avant validation.
 */
@Service
@Slf4j
public class MapboxGeocodingService {

    /** Abidjan — centre de gravité de l'essentiel des trajets desservis actuellement. */
    private static final String PROXIMITY_ABIDJAN = "-4.0083,5.3600";

    private final RestClient restClient;

    @Value("${mapbox.access-token}")
    private String accessToken;

    public MapboxGeocodingService(RestClient.Builder restClientBuilder) {
        this.restClient = restClientBuilder
                .baseUrl("https://api.mapbox.com/geocoding/v5/mapbox.places")
                .build();
    }

    public GeocodingResult geocode(String query) {
        log.info("🚀 Requête Mapbox Geocoding : '{}'", query);
        String encodedQuery = java.net.URLEncoder.encode(query, StandardCharsets.UTF_8);

        Map<String, Object> body = restClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/{query}.json")
                        .queryParam("access_token", accessToken)
                        .queryParam("proximity", PROXIMITY_ABIDJAN)
                        .queryParam("limit", 1)
                        .build(encodedQuery))
                .retrieve()
                .body(Map.class);

        if (body == null) {
            throw new GeocodingFailedException("Réponse Mapbox Geocoding vide pour '" + query + "'.");
        }

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> features = (List<Map<String, Object>>) body.get("features");
        if (features == null || features.isEmpty()) {
            log.warn("⚠️ Mapbox Geocoding : aucun résultat pour '{}'.", query);
            throw new GeocodingFailedException("Aucun résultat Mapbox Geocoding pour '" + query + "'.");
        }

        @SuppressWarnings("unchecked")
        List<Number> center = (List<Number>) features.get(0).get("center");
        if (center == null || center.size() != 2) {
            throw new GeocodingFailedException("Réponse Mapbox Geocoding sans coordonnées pour '" + query + "'.");
        }

        // Mapbox renvoie [longitude, latitude] dans "center" (contre-intuitif, comme pour
        // Directions — voir MapboxDirectionsService).
        double lng = center.get(0).doubleValue();
        double lat = center.get(1).doubleValue();
        log.info(String.format(Locale.ROOT, "✅ Mapbox Geocoding '%s' -> %.4f, %.4f", query, lat, lng));
        return new GeocodingResult(lat, lng);
    }
}
