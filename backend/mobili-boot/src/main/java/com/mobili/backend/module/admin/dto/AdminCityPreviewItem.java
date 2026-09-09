package com.mobili.backend.module.admin.dto;

/**
 * Une ligne de l'écran admin Pays & Villes — toujours renvoyée, que le géocodage ait réussi ou
 * non (jamais d'exception qui casserait tout l'aperçu pour une seule ville en échec). Même
 * principe que GeocodingPreviewItem (écran admin de géocodage des arrêts de trajet), adapté pour
 * cibler une vraie ligne `City` (id) plutôt qu'un simple city_label de TripStop.
 *
 * {@code ambiguous} : nom connu pour exister dans plusieurs pays (ex. "Touba" — Sénégal ET
 * Côte d'Ivoire) sans pays déjà renseigné pour trancher — l'admin doit vérifier manuellement.
 */
public record AdminCityPreviewItem(
        Long id,
        String name,
        Long countryId,
        String countryName,
        Double latitude,
        Double longitude,
        boolean ambiguous,
        String errorMessage) {

    public static AdminCityPreviewItem success(
            Long id, String name, Long countryId, String countryName,
            double lat, double lng, boolean ambiguous) {
        return new AdminCityPreviewItem(id, name, countryId, countryName, lat, lng, ambiguous, null);
    }

    public static AdminCityPreviewItem failure(
            Long id, String name, Long countryId, String countryName, String errorMessage) {
        return new AdminCityPreviewItem(id, name, countryId, countryName, null, null, false, errorMessage);
    }
}
