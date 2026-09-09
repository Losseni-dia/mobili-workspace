package com.mobili.backend.module.admin.dto;

/**
 * Une ligne de l'écran admin de géocodage — toujours renvoyée, que le géocodage ait réussi ou
 * non (jamais d'exception qui casserait tout l'aperçu pour une seule ville en échec).
 *
 * {@code ambiguous} : nom connu pour exister dans plusieurs pays (ex. "Touba" — Sénégal ET
 * Côte d'Ivoire) — la recherche Mapbox par nom seul ne peut pas trancher, l'admin doit vérifier
 * manuellement avant de valider cette ligne à l'écran.
 */
public record GeocodingPreviewItem(
        String cityLabel,
        Double latitude,
        Double longitude,
        boolean ambiguous,
        String errorMessage) {

    public static GeocodingPreviewItem success(String cityLabel, double lat, double lng, boolean ambiguous) {
        return new GeocodingPreviewItem(cityLabel, lat, lng, ambiguous, null);
    }

    public static GeocodingPreviewItem failure(String cityLabel, String errorMessage) {
        return new GeocodingPreviewItem(cityLabel, null, null, false, errorMessage);
    }

    public static GeocodingPreviewItem excludedAsTestData(String cityLabel) {
        return new GeocodingPreviewItem(cityLabel, null, null, false,
                "Exclu automatiquement (ressemble à une donnée de test) — à vérifier manuellement si besoin.");
    }
}
