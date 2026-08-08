package com.mobili.backend.module.payment.dto;

import com.mobili.backend.module.payment.enums.PaymentProvider;

public record PaymentRequest(
    PaymentProvider provider,
    String customerEmail
) {}
