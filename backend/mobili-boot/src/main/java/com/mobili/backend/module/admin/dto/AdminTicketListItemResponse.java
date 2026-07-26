package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;

public record AdminTicketListItemResponse(
        Long id,
        String ticketNumber,
        String passengerName,
        String route,
        String partnerName,
        LocalDateTime bookingDate,
        Double amountPaid,
        String status,
        String seatNumber,
        boolean scanned) {
}