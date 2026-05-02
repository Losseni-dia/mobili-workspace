package com.mobili.backend.module.booking.booking.projection;

/**
 * Cible d'une requête JPQL {@code new ...} pour les agrégats période (évite
 * {@code Object[]} et les casts implicites incompatibles avec Hibernate 6).
 */
public final class TripStatsAggrJpa {
    private final double totalRevenue;
    private final long totalBookings;
    private final long distinctTrips;

    public TripStatsAggrJpa(Double totalRevenue, Long totalBookings, Long distinctTrips) {
        this.totalRevenue = totalRevenue != null ? totalRevenue : 0.0;
        this.totalBookings = totalBookings != null ? totalBookings : 0L;
        this.distinctTrips = distinctTrips != null ? distinctTrips : 0L;
    }

    public double getTotalRevenue() {
        return totalRevenue;
    }

    public long getTotalBookings() {
        return totalBookings;
    }

    public long getDistinctTrips() {
        return distinctTrips;
    }
}
