package com.mobili.backend.module.routing.exception;

/**
 * Levée quand Mapbox Geocoding n'a renvoyé aucun résultat exploitable pour une requête (ville
 * introuvable, ou réponse vide) — voir MapboxGeocodingService. Jamais transformée en coordonnée
 * approximative : l'appelant (AdminTripStopGeocodingService) doit afficher "échec" à l'admin.
 */
public class GeocodingFailedException extends RuntimeException {
    public GeocodingFailedException(String message) {
        super(message);
    }
}
