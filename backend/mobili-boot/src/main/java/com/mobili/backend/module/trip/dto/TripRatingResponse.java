package com.mobili.backend.module.trip.dto;

import java.time.LocalDateTime;

public record TripRatingResponse(
        Long id,
        Long tripId,
        Short note,
        String comment,
        LocalDateTime createdAt) {
}
