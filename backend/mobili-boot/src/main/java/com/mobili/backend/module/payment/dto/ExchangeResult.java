package com.mobili.backend.module.payment.dto;

import java.math.BigDecimal;

public record ExchangeResult(
        BigDecimal convertedAmount,
        BigDecimal exchangeRate,
        String sourceCurrency,
        String targetCurrency
) {}
