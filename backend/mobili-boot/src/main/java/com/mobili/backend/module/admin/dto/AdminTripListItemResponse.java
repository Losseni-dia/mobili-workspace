package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;

public record AdminTripListItemResponse(
        Long id,
        String route,
        String partnerName,
        String stationName,
        LocalDateTime departureDateTime,
        Integer totalSeats,
        Integer availableSeats,
        Double price,
        String status) {
}