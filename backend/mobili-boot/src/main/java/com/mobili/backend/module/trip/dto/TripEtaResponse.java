package com.mobili.backend.module.trip.dto;

import com.mobili.backend.module.routing.dto.DirectionsResult;

/**
 * Réponse de GET /trips/{tripId}/eta. {@code available = false} quand le prochain arrêt n'a pas
 * de coordonnées renseignées (voir TripStop.latitude/longitude) — jamais une estimation
 * approximative dans ce cas, juste "indisponible".
 */
public record TripEtaResponse(
        boolean available,
        String destinationCity,
        Long durationSeconds,
        Double distanceMeters,
        String provider) {

    public static TripEtaResponse unavailable(String destinationCity) {
        return new TripEtaResponse(false, destinationCity, null, null, null);
    }

    public static TripEtaResponse available(String destinationCity, DirectionsResult result) {
        return new TripEtaResponse(
                true, destinationCity, result.durationSeconds(), result.distanceMeters(),
                result.provider().name());
    }
}
