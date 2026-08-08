package com.mobili.backend.module.payment.stripe.dto;

public record StripeCheckoutRequest(Long amount, String currency, String customerEmail) {
}
