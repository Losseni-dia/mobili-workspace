package com.mobili.backend.module.booking.booking.dto;

import com.mobili.backend.module.booking.booking.service.BookingService.PricingBreakdown;

/**
 * Détail affichable au passager avant paiement : sous-total sièges (post-coupon), forfait
 * client, frais bagages, total final — jamais un total opaque.
 */
public record BookingPricePreviewResponse(
        double seatSubtotal, int serviceFee, double luggageFee, double total) {

    public static BookingPricePreviewResponse from(PricingBreakdown pricing) {
        return new BookingPricePreviewResponse(
                pricing.seatSubtotal(), pricing.serviceFee(), pricing.luggageFee(), pricing.total());
    }
}
