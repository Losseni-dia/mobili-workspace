package com.mobili.backend.module.admin.dto;

/**
 * Part du CA pour le graphique circulaire (top trajets + reste).
 */
public record RevenueDonutSliceResponse(
        String label,
        double revenueFcfa,
        double percentOfTotal) {
}
