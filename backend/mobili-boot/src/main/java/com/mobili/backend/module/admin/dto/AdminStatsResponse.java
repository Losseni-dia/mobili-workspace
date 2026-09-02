package com.mobili.backend.module.admin.dto;

public record AdminStatsResponse(
        long totalUsers,
        long totalPartners,
        long totalTrips,
        /** Trajets dont le départ tombe dans l'année civile en cours — quel que soit le statut,
         *  comparable à "Trajets avec ventes" de Stats métier (même année, même filtre sur la
         *  date de départ). totalTrips (all-time, sans filtre) reste inchangé à côté. */
        long totalTripsThisYear,
        /** = totalTripsThisYear - (nombre de trajets distincts avec au moins 1 ticket vendu sur
         *  l'année) : trajets publiés cette année qui n'ont encore rien vendu. */
        long tripsWithoutSalesThisYear,
        long totalTickets,
        long activeBookings,
        double totalRevenue,
        /** Répartition du CA all-time par canal — mêmes statuts que côté partenaire (CONFIRMED
         *  = en ligne, OFFLINE_SALE = guichet), somme de b.totalPrice (cohérent avec totalRevenue
         *  ci-dessus, pas un recalcul par ticket actif comme Booking.getGrossAmount()). */
        double revenueOnline,
        double revenueOffline) {
}