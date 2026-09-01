package com.mobili.backend.module.admin.dto;

public record AdminStatsResponse(
        long totalUsers,
        long totalPartners,
        long totalTrips,
        long totalTickets,
        long activeBookings,
        double totalRevenue,
        /** Répartition du CA all-time par canal — mêmes statuts que côté partenaire (CONFIRMED
         *  = en ligne, OFFLINE_SALE = guichet), somme de b.totalPrice (cohérent avec totalRevenue
         *  ci-dessus, pas un recalcul par ticket actif comme Booking.getGrossAmount()). */
        double revenueOnline,
        double revenueOffline) {
}