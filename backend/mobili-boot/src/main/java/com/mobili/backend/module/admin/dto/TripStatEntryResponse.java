package com.mobili.backend.module.admin.dto;

/**
 * Ligne de classement d'un trajet (billets vendus / chiffre d'affaires). ticketCount compte des
 * TICKETS (unité = un siège), jamais des réservations — une résa de 3 places = 1 booking mais
 * 3 tickets (voir TicketRepository.countActiveTicketsForPeriod).
 */
public record TripStatEntryResponse(
        int rank,
        long tripId,
        String route,
        String partnerName,
        String stationName,
        long ticketCount,
        double revenueFcfa) {
}
