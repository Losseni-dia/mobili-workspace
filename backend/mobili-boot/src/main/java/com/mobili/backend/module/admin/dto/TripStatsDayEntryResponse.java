package com.mobili.backend.module.admin.dto;

import java.time.LocalDate;

/**
 * Un point de la courbe de croissance (Stats métier) — un jour civil, sur la date de départ du
 * trajet (voir BookingRepository.dailyTripStatsBetween).
 */
public record TripStatsDayEntryResponse(
        LocalDate date,
        long bookingCount,
        double revenueFcfa) {
}
