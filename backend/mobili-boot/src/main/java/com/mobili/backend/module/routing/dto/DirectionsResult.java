package com.mobili.backend.module.routing.dto;

import com.mobili.backend.module.routing.enums.DirectionsProvider;

/**
 * Résultat d'un calcul d'itinéraire — durée/distance du trajet restant, et le fournisseur qui a
 * effectivement répondu (Mapbox en temps normal, Google Maps en cas de bascule) : conservé
 * jusque dans la réponse pour permettre un affichage/log clair côté appelant.
 */
public record DirectionsResult(
        long durationSeconds,
        double distanceMeters,
        DirectionsProvider provider) {
}
