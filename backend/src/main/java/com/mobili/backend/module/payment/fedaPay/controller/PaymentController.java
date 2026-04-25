package com.mobili.backend.module.payment.fedaPay.controller;

import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.payment.fedaPay.dto.PaymentVerifyResponse;
import com.mobili.backend.module.payment.fedaPay.service.FedaPayService;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

@RestController
@RequestMapping("v1/payments")
@RequiredArgsConstructor
@Slf4j
public class PaymentController {

    @Value("${FEDAPAY_WEBHOOK_SECRET}")
    private String webhookSecret;

    private final BookingService bookingService;
    private final FedaPayService fedaPayService;


    @PostMapping("/checkout/{bookingId}")
    public ResponseEntity<Map<String, String>> createCheckout(@PathVariable("bookingId") Long bookingId) {
        log.info("🚀 Requête de paiement reçue pour le Booking ID: {}", bookingId);

        var booking = bookingService.findById(bookingId);

        var session = fedaPayService.createPaymentSession(
                booking.getTotalPrice(),
                booking.getCustomer().getEmail(),
                bookingId);
        bookingService.recordFedaPayTransactionId(bookingId, session.transactionId());
        return ResponseEntity.ok(Map.of("url", session.paymentUrl()));
    }

    /**
     * Appel côté client après retour FedaPay (le webhook n'atteint souvent pas localhost en dev).
     * Relit le statut sur l'API FedaPay, puis confirme la réservation et génère les billets si approuvé.
     */
    @PostMapping("/verify/{bookingId}")
    public ResponseEntity<PaymentVerifyResponse> verifyAndConfirm(
            @PathVariable("bookingId") Long bookingId) {
        Booking booking = bookingService.findById(bookingId);
        BookingStatus st = booking.getStatus();
        if (st == BookingStatus.CONFIRMED || st == BookingStatus.COMPLETED) {
            return ResponseEntity.ok(new PaymentVerifyResponse(true, st.name()));
        }
        if (st != BookingStatus.PENDING) {
            return ResponseEntity.ok(new PaymentVerifyResponse(false, st.name()));
        }
        String txId = booking.getFedapayTransactionId();
        if (txId == null || txId.isBlank()) {
            log.warn("Vérification FedaPay impossible : pas d'ID transaction enregistré (bookingId={})",
                    bookingId);
            return ResponseEntity.ok(new PaymentVerifyResponse(false, BookingStatus.PENDING.name()));
        }
        if (fedaPayService.isTransactionApprovedForBooking(txId)) {
            bookingService.confirmFedaPayPayment(bookingId);
            return ResponseEntity.ok(new PaymentVerifyResponse(true, BookingStatus.CONFIRMED.name()));
        }
        return ResponseEntity.ok(new PaymentVerifyResponse(false, BookingStatus.PENDING.name()));
    }

    @PostMapping("/callback")
    public ResponseEntity<Void> handleWebhook(
            @RequestBody Map<String, Object> payload,
            @RequestHeader(value = "X-Webhook-Secret", required = false) String secret) {

        if (!secureEquals(webhookSecret, secret)) {
            log.error("❌ Secret Webhook incorrect !");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        try {
            Map<String, Object> entity = asStringObjectMap(payload.get("entity"));
            if (entity == null)
                return ResponseEntity.ok().build();

            String status = (String) entity.get("status");

            if ("approved".equals(status)) {
                Map<String, Object> metadata = asStringObjectMap(entity.get("custom_metadata"));
                if (metadata != null && metadata.containsKey("booking_id")) {

                    // Extraction sécurisée de l'ID
                    Long bookingId = Long.valueOf(metadata.get("booking_id").toString());

                    // ✅ APPEL AU SERVICE POUR VALIDER ET GÉNÉRER LES TICKETS
                    bookingService.confirmFedaPayPayment(bookingId);
                }
            }
            return ResponseEntity.ok().build();

        } catch (Exception e) {
            log.error("💥 Erreur Webhook: {}", e.getMessage());
            return ResponseEntity.internalServerError().build();
        }
    }

    private boolean secureEquals(String expected, String provided) {
        if (expected == null || provided == null) {
            return false;
        }
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                provided.getBytes(StandardCharsets.UTF_8));
    }

    private Map<String, Object> asStringObjectMap(Object source) {
        if (!(source instanceof Map<?, ?> rawMap)) {
            return null;
        }
        return rawMap.entrySet().stream()
                .filter(entry -> entry.getKey() instanceof String)
                .collect(java.util.stream.Collectors.toMap(
                        entry -> (String) entry.getKey(),
                        Map.Entry::getValue));
    }
}