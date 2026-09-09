package com.mobili.backend.module.routing.mapbox.dto;

/** Résultat d'un géocodage Mapbox réussi — pas d'itinéraire ici, juste un point. */
public record GeocodingResult(double latitude, double longitude) {
}
