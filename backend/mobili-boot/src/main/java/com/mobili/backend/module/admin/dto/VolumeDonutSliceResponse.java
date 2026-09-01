package com.mobili.backend.module.admin.dto;

/**
 * Part des billets (tickets, pas réservations) par trajet pour un graphique circulaire.
 */
public record VolumeDonutSliceResponse(
        String label,
        long ticketCount,
        double percentOfTotal) {
}
