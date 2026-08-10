package com.mobili.backend.module.claim.enums;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class ClaimReasonTest {

    @Test
    void bookingRelatedReasons_requireBooking() {
        assertTrue(ClaimReason.REFUND_REQUEST.requiresBooking());
        assertTrue(ClaimReason.CANCELLATION.requiresBooking());
        assertTrue(ClaimReason.DELAY.requiresBooking());
        assertTrue(ClaimReason.DRIVER_ISSUE.requiresBooking());
    }

    @Test
    void freeformReasons_doNotRequireBooking() {
        assertFalse(ClaimReason.LOST_ITEM.requiresBooking());
        assertFalse(ClaimReason.OTHER.requiresBooking());
    }
}
