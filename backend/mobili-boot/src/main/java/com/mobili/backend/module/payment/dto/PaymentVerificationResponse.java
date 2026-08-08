package com.mobili.backend.module.payment.dto;

public record PaymentVerificationResponse(
        String paymentStatus,
        String bookingStatus,
        boolean ticketAvailable
) {}
