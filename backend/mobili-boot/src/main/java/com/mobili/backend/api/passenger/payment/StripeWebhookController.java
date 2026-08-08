package com.mobili.backend.api.passenger.payment;

import com.mobili.backend.module.payment.service.PaymentConfirmationService;
import com.mobili.backend.module.payment.service.PaymentStatusUpdateService;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Event;
import com.stripe.model.EventDataObjectDeserializer;
import com.stripe.model.PaymentIntent;
import com.stripe.model.checkout.Session;
import com.stripe.net.Webhook;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/payments/stripe")
@Slf4j
@RequiredArgsConstructor
public class StripeWebhookController {

    @Value("${stripe.webhook-secret}")
    private String webhookSecret;

    private final PaymentStatusUpdateService paymentStatusUpdateService;
    private final PaymentConfirmationService paymentConfirmationService;

    @PostMapping("/webhook")
    public ResponseEntity<String> handleWebhook(
            @RequestBody String payload,
            @RequestHeader("Stripe-Signature") String sigHeader) {

        log.info("🔔 Réception événement Stripe Webhook");

        Event event;
        try {
            event = Webhook.constructEvent(payload, sigHeader, webhookSecret);
        } catch (SignatureVerificationException e) {
            log.error("❌ Erreur signature Webhook Stripe : {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Signature invalide");
        }

        EventDataObjectDeserializer dataObjectDeserializer = event.getDataObjectDeserializer();
        if (dataObjectDeserializer.getObject().isEmpty()) {
            log.error("❌ Données d'événement introuvables");
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Données invalides");
        }

        String eventType = event.getType();
        log.info("✅ Événement type : {}", eventType);

        if ("checkout.session.completed".equals(eventType)) {
            Session session = (Session) dataObjectDeserializer.getObject().get();
            String bookingIdStr = session.getMetadata().get("booking_id");
            String paymentIntentId = session.getPaymentIntent();

            if (bookingIdStr == null || paymentIntentId == null) {
                log.error("❌ Données manquantes: BookingID={}, PI={}", bookingIdStr, paymentIntentId);
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Données manquantes");
            }

            Long bookingId = Long.valueOf(bookingIdStr);
            log.info("📦 Session complétée. Booking ID: {}, PI: {}", bookingId, paymentIntentId);

            // 1. Marquer succès + enregistrer référence
            paymentStatusUpdateService.markAsSuccessWithReference(bookingId, paymentIntentId);

            // 2. Confirmer métier
            paymentConfirmationService.confirmPayment(paymentIntentId);
            
        } else if ("checkout.session.async_payment_failed".equals(eventType)) {
            Session session = (Session) dataObjectDeserializer.getObject().get();
            String paymentIntentId = session.getPaymentIntent();
            log.warn("⚠️ Paiement asynchrone échoué (Checkout Session). PI: {}", paymentIntentId);
            if (paymentIntentId != null) {
                paymentStatusUpdateService.markAsFailed(paymentIntentId);
            }
        } else if ("payment_intent.payment_failed".equals(eventType)) {
            PaymentIntent pi = (PaymentIntent) dataObjectDeserializer.getObject().get();
            log.warn("⚠️ Paiement échoué (Payment Intent). PI: {}", pi.getId());
            paymentStatusUpdateService.markAsFailed(pi.getId());
        }

        return ResponseEntity.ok("Success");
    }
}
