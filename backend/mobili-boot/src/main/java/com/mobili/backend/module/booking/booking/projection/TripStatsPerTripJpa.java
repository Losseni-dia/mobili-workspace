package com.mobili.backend.module.booking.booking.projection;

/**
 * Cible d'une requête JPQL {@code new ...} pour un trajet (stats agrégées).
 */
public final class TripStatsPerTripJpa {
    private final long tripId;
    private final String departureCity;
    private final String arrivalCity;
    private final String partnerName;
    private final long bookingCount;
    private final double revenue;

    public TripStatsPerTripJpa(
            Long tripId,
            String departureCity,
            String arrivalCity,
            String partnerName,
            Long bookingCount,
            Double revenue) {
        this.tripId = tripId != null ? tripId : 0L;
        this.departureCity = departureCity;
        this.arrivalCity = arrivalCity;
        this.partnerName = partnerName;
        this.bookingCount = bookingCount != null ? bookingCount : 0L;
        this.revenue = revenue != null ? revenue : 0.0;
    }

    public long getTripId() {
        return tripId;
    }

    public String getDepartureCity() {
        return departureCity;
    }

    public String getArrivalCity() {
        return arrivalCity;
    }

    public String getPartnerName() {
        return partnerName;
    }

    public long getBookingCount() {
        return bookingCount;
    }

    public double getRevenue() {
        return revenue;
    }
}
