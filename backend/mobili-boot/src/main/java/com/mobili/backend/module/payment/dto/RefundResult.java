package com.mobili.backend.module.payment.dto;

import java.math.BigDecimal;

public record RefundResult(
        boolean success,
        String externalReference,
        String message
) {}
