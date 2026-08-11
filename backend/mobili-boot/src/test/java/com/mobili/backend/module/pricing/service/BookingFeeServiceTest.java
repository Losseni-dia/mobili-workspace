package com.mobili.backend.module.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class BookingFeeServiceTest {

    private final BookingFeeService service = new BookingFeeService();

    @Test
    void belowLowThreshold_returnsLowFee() {
        assertEquals(100, service.calculateBookingFee(2500));
    }

    @Test
    void exactlyLowThreshold_returnsLowFee() {
        // Borne haute incluse dans le palier bas : 3000 -> 100, pas 200.
        assertEquals(100, service.calculateBookingFee(3000));
    }

    @Test
    void justAboveLowThreshold_returnsMidFee() {
        assertEquals(200, service.calculateBookingFee(3001));
    }

    @Test
    void justBelowHighThreshold_returnsMidFee() {
        assertEquals(200, service.calculateBookingFee(6999));
    }

    @Test
    void exactlyHighThreshold_returnsHighFee() {
        // Borne basse incluse dans le palier haut : 7000 -> 300, pas 200.
        assertEquals(300, service.calculateBookingFee(7000));
    }

    @Test
    void fourTicketsAt3000_totalsTwelveThousand_returnsHighFee() {
        assertEquals(300, service.calculateBookingFee(4 * 3000));
    }

    @Test
    void twoTicketsAt5000_totalsTenThousand_returnsHighFee() {
        assertEquals(300, service.calculateBookingFee(2 * 5000));
    }

    @Test
    void veryLargeAmount_isCappedAtHighFee() {
        // Plafond assumé : pas de palier au-delà de 300, même pour un montant très élevé.
        assertEquals(300, service.calculateBookingFee(3 * 25000));
    }
}
