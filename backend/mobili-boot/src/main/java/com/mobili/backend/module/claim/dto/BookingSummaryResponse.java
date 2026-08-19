package com.mobili.backend.module.claim.dto;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.util.BookingSegmentUtil;

import java.time.LocalDateTime;

/**
 * Résumé de la réservation liée, recalculé à la lecture depuis la relation réelle
 * (Claim.booking) — jamais figé/dupliqué au moment de la réclamation, pour toujours
 * refléter l'état actuel (statut, etc.) plutôt qu'un instantané qui pourrait désynchroniser.
 */
public record BookingSummaryResponse(
        Long bookingId,
        String reference,
        String route,
        Double totalPrice,
        LocalDateTime bookingDate,
        String status) {

    public static BookingSummaryResponse from(Booking booking) {
        return new BookingSummaryResponse(
                booking.getId(),
                booking.getReference(),
                BookingSegmentUtil.resolveRouteLabel(booking),
                booking.getTotalPrice(),
                booking.getBookingDate(),
                booking.getStatus() != null ? booking.getStatus().name() : "—");
    }
}
