package com.mobili.backend.module.trip.dto;

import java.util.List;

public record TripPricePreviewResponse(
        double pricePerSeat,
        int lastStopIndex,
        List<TripStopResponseDTO> stops) {
}
