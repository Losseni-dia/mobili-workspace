package com.mobili.backend.module.payment.dto;

import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.enums.PaymentStatus;

public record PaymentResponse(
        Long paymentId,
        Long bookingId,
        PaymentProvider provider,
        PaymentStatus status,
        String paymentUrl,
        String clientSecret,
        Long amount,
        String currency
) {}
