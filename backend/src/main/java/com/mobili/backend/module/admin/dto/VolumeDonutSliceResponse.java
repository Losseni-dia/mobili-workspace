package com.mobili.backend.module.admin.dto;

/**
 * Part des réservations (volume) par trajet pour un graphique circulaire.
 */
public record VolumeDonutSliceResponse(
        String label,
        long bookingCount,
        double percentOfTotal) {
}
