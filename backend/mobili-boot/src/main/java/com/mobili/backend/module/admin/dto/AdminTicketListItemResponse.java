package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;

public record AdminTicketListItemResponse(
        Long id,
        String ticketNumber,
        String passengerName,
        String route,
        String partnerName,
        LocalDateTime bookingDate,
        /** Date de départ du voyage — distincte de bookingDate (date d'achat), voir
         *  PartnerTicketResponse.departureDateTime pour la justification. */
        LocalDateTime departureDateTime,
        Double amountPaid,
        String status,
        String seatNumber,
        boolean scanned) {
}