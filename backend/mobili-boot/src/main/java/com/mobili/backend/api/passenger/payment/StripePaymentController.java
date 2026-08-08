package com.mobili.backend.api.passenger.payment;

import com.mobili.backend.module.payment.stripe.dto.StripeCheckoutRequest;
import com.mobili.backend.module.payment.stripe.service.StripeService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/payments/stripe")
@RequiredArgsConstructor
@Slf4j
public class StripePaymentController {

    private final StripeService stripeService;

    @PostMapping("/checkout/{bookingId}")
    public ResponseEntity<Map<String, String>> createCheckout(
            @PathVariable("bookingId") Long bookingId,
            @RequestBody StripeCheckoutRequest request) {
        log.info("🚀 Requête de paiement Stripe reçue pour le Booking ID: {}", bookingId);

        String url = stripeService.createCheckoutSession(
                bookingId,
                request.amount(),
                request.currency(),
                request.customerEmail());

        return ResponseEntity.ok(Map.of("paymentUrl", url));
    }
}
