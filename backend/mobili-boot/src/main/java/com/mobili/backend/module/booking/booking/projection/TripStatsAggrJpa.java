package com.mobili.backend.module.booking.booking.projection;

/**
 * Cible d'une requête JPQL {@code new ...} pour les agrégats période (évite
 * {@code Object[]} et les casts implicites incompatibles avec Hibernate 6).
 */
public final class TripStatsAggrJpa {
    private final double totalRevenue;
    private final long totalBookings;
    private final long distinctTrips;
    private final double revenueOnline;
    private final double revenueOffline;
    private final double totalServiceFee;

    public TripStatsAggrJpa(Double totalRevenue, Long totalBookings, Long distinctTrips) {
        this(totalRevenue, totalBookings, distinctTrips, 0.0, 0.0, 0.0);
    }

    public TripStatsAggrJpa(Double totalRevenue, Long totalBookings, Long distinctTrips,
            Double revenueOnline, Double revenueOffline, Double totalServiceFee) {
        this.totalRevenue = totalRevenue != null ? totalRevenue : 0.0;
        this.totalBookings = totalBookings != null ? totalBookings : 0L;
        this.distinctTrips = distinctTrips != null ? distinctTrips : 0L;
        this.revenueOnline = revenueOnline != null ? revenueOnline : 0.0;
        this.revenueOffline = revenueOffline != null ? revenueOffline : 0.0;
        this.totalServiceFee = totalServiceFee != null ? totalServiceFee : 0.0;
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

    public double getRevenueOnline() {
        return revenueOnline;
    }

    public double getRevenueOffline() {
        return revenueOffline;
    }

    public double getTotalServiceFee() {
        return totalServiceFee;
    }
}
