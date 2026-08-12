package com.mobili.backend.module.payment.stripe.service;

import com.mobili.backend.module.payment.dto.RefundResult;
import com.mobili.backend.module.payment.enums.PaymentProvider;
import com.mobili.backend.module.payment.service.PaymentService;
import lombok.extern.slf4j.Slf4j;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class StripePaymentService implements PaymentService {

    private final StripeService stripeService;

    @Override
    public String createPaymentSession(Long bookingId, Long amount, String currency, String customerEmail) {
        // Conversion unités réelles (ex: 23 EUR) -> centimes (2300) pour Stripe
        Long amountInCents = amount * 100;
        return stripeService.createCheckoutSession(bookingId, amountInCents, currency, customerEmail);
    }

    @Override
    public RefundResult refundPayment(String externalReference) {
        log.info("💳 Appel remboursement Stripe pour référence: {}", externalReference);
        try {
            String refundId = stripeService.refundPayment(externalReference);
            return new RefundResult(true, refundId, "Remboursement Stripe réussi");
        } catch (Exception e) {
            log.error("💥 Erreur remboursement Stripe : {}", e.getMessage());
            return new RefundResult(false, null, e.getMessage());
        }
    }

    /**
     * Remboursement partiel — montant en FCFA (même unité que createPaymentSession), converti
     * en centimes ici avec la même conversion *100, jamais dupliquée ailleurs.
     */
    @Override
    public RefundResult refundPayment(String externalReference, Long amount) {
        log.info("💳 Appel remboursement partiel Stripe pour référence: {} ({} FCFA)",
                externalReference, amount);
        try {
            Long amountInCents = amount != null ? amount * 100 : null;
            String refundId = stripeService.refundPayment(externalReference, amountInCents);
            return new RefundResult(true, refundId, "Remboursement Stripe réussi");
        } catch (Exception e) {
            log.error("💥 Erreur remboursement Stripe : {}", e.getMessage());
            return new RefundResult(false, null, e.getMessage());
        }
    }

    @Override
    public PaymentProvider getPaymentProvider() {
        return PaymentProvider.STRIPE;
    }
}
