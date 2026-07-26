package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;

public record AdminBookingListItemResponse(
        Long id,
        String reference,
        String customerName,
        String route,
        String partnerName,
        LocalDateTime bookingDate,
        Integer numberOfSeats,
        Double totalPrice,
        String status) {
}