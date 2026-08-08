package com.mobili.backend.module.payment.service;

import com.mobili.backend.module.payment.dto.ExchangeResult;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Service
@Slf4j
public class ExchangeRateService {

    private final BigDecimal xofEurRate;

    public ExchangeRateService(@Value("${payment.exchange.xof-eur-rate}") BigDecimal xofEurRate) {
        this.xofEurRate = xofEurRate;
    }

    public ExchangeResult convert(Long amount, String fromCurrency, String toCurrency) {
        if (fromCurrency.equals(toCurrency)) {
            return new ExchangeResult(BigDecimal.valueOf(amount), BigDecimal.ONE, fromCurrency, toCurrency);
        }

        if ("XOF".equals(fromCurrency) && "EUR".equals(toCurrency)) {
            // Conversion XOF -> EUR : Amount / Rate
            BigDecimal rate = BigDecimal.ONE.divide(xofEurRate, 6, RoundingMode.HALF_UP);
            BigDecimal convertedAmount = BigDecimal.valueOf(amount).multiply(rate).setScale(2, RoundingMode.HALF_UP);
            return new ExchangeResult(convertedAmount, rate, fromCurrency, toCurrency);
        }

        log.error("❌ Conversion non supportée : {} -> {}", fromCurrency, toCurrency);
        throw new IllegalArgumentException("Unsupported currency conversion: " + fromCurrency + " -> " + toCurrency);
    }
}
