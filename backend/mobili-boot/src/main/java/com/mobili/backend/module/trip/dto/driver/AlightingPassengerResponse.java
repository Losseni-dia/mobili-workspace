package com.mobili.backend.module.trip.dto.driver;

public record AlightingPassengerResponse(
        String ticketNumber,
        String passengerName,
        String seatNumber,
        String ticketStatus,
        int boardingStopIndex) {
}
