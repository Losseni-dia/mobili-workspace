package com.mobili.backend.module.admin.dto;

/**
 * Ligne de classement d'un trajet (réservations / chiffre d'affaires).
 */
public record TripStatEntryResponse(
        int rank,
        long tripId,
        String route,
        String partnerName,
        long bookingCount,
        double revenueFcfa) {
}
