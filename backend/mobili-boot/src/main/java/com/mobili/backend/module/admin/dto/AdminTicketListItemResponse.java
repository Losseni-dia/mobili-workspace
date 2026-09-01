package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;

public record AdminTicketListItemResponse(
        Long id,
        String ticketNumber,
        String passengerName,
        String route,
        String partnerName,
        String stationName,
        LocalDateTime bookingDate,
        /** Date de départ du voyage — distincte de bookingDate (date d'achat), voir
         *  PartnerTicketResponse.departureDateTime pour la justification. */
        LocalDateTime departureDateTime,
        Double amountPaid,
        String status,
        String seatNumber,
        boolean scanned,
        /** Statut de la réservation d'origine (CONFIRMED/OFFLINE_SALE/...) — distingue vente en
         *  ligne / guichet, voir PartnerTicketResponse.bookingStatus. */
        String bookingStatus) {
}