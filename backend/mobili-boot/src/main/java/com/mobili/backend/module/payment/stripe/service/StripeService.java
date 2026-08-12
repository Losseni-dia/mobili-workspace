package com.mobili.backend.module.payment.stripe.service;

import com.stripe.model.Refund;
import com.stripe.model.checkout.Session;
import com.stripe.param.RefundCreateParams;
import com.stripe.param.checkout.SessionCreateParams;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class StripeService {

    /**
     * Crée une session de paiement Stripe Checkout.
     * Le SDK Stripe est configuré globalement par StripeConfig.
     */
    public String createCheckoutSession(Long bookingId, Long amount, String currency, String customerEmail) {
        log.info("🚀 Création session Stripe pour Booking #{}", bookingId);

        try {
            SessionCreateParams.Builder builder = SessionCreateParams.builder()
                    .addPaymentMethodType(SessionCreateParams.PaymentMethodType.CARD)
                    .setMode(SessionCreateParams.Mode.PAYMENT)
                    .setSuccessUrl("https://api.my-mobili.com/v1/payments/stripe/success?session_id={CHECKOUT_SESSION_ID}")
                    .setCancelUrl("https://api.my-mobili.com/v1/payments/stripe/cancel")
                    .addLineItem(
                            SessionCreateParams.LineItem.builder()
                                    .setQuantity(1L)
                                    .setPriceData(
                                            SessionCreateParams.LineItem.PriceData.builder()
                                                    .setCurrency(currency.toLowerCase())
                                                    .setUnitAmount(amount)
                                                    .setProductData(
                                                            SessionCreateParams.LineItem.PriceData.ProductData.builder()
                                                                    .setName("Booking Payment #" + bookingId)
                                                                    .build()
                                                    )
                                                    .build()
                                    )
                                    .build()
                    )
                    .putMetadata("booking_id", String.valueOf(bookingId));

            if (customerEmail != null && !customerEmail.isBlank()) {
                builder.setCustomerEmail(customerEmail.trim());
            }

            Session session = Session.create(builder.build());
            log.info("✅ Session Stripe créée avec succès: {}", session.getId());
            return session.getUrl();

        } catch (Exception e) {
            log.error("💥 Erreur Stripe : {} - {}", e.getClass().getSimpleName(), e.getMessage());
            throw new RuntimeException("Échec Stripe : " + e.getMessage());
        }
    }

    public String refundPayment(String paymentIntentId) {
        return refundPayment(paymentIntentId, null);
    }

    /**
     * @param amountInCents null = remboursement intégral (comportement historique) ; sinon
     *                      remboursement partiel, déjà converti dans l'unité mineure Stripe
     *                      (même conversion *100 que StripePaymentService.createPaymentSession).
     */
    public String refundPayment(String paymentIntentId, Long amountInCents) {
        log.info("💳 Tentative de remboursement Stripe pour PaymentIntent: {} (montant={})",
                paymentIntentId, amountInCents == null ? "intégral" : amountInCents);
        try {
            RefundCreateParams.Builder builder = RefundCreateParams.builder()
                    .setPaymentIntent(paymentIntentId);
            if (amountInCents != null) {
                builder.setAmount(amountInCents);
            }
            Refund refund = Refund.create(builder.build());
            log.info("✅ Remboursement Stripe réussi: {}", refund.getId());
            return refund.getId();
        } catch (Exception e) {
            log.error("💥 Erreur remboursement Stripe : {}", e.getMessage());
            throw new RuntimeException("Échec remboursement Stripe : " + e.getMessage());
        }
    }
}
