package com.mobili.backend.module.booking.ticket.dto;

import java.time.LocalDateTime;

public record PartnerTicketResponse(
        Long id,
        String ticketNumber,
        String passengerName,
        String route,
        String stationName,
        LocalDateTime bookingDate,
        Double amountPaid,
        String status,
        String seatNumber,
        boolean scanned) {
}