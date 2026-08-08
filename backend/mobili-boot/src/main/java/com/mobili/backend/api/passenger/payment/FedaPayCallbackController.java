package com.mobili.backend.api.passenger.payment;

import com.mobili.backend.module.payment.service.PaymentConfirmationService;
import com.mobili.backend.module.payment.service.PaymentStatusUpdateService;
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
@RequestMapping("/payments/fedapay")
@Slf4j
@RequiredArgsConstructor
public class FedaPayCallbackController {

    @Value("${FEDAPAY_WEBHOOK_SECRET}")
    private String webhookSecret;

    private final PaymentStatusUpdateService paymentStatusUpdateService;
    private final PaymentConfirmationService paymentConfirmationService;

    @PostMapping("/callback")
    public ResponseEntity<Void> handleWebhook(
            @RequestBody Map<String, Object> payload,
            @RequestHeader(value = "X-Webhook-Secret", required = false) String secret) {

        if (!secureEquals(webhookSecret, secret)) {
            log.error("❌ Secret Webhook FedaPay incorrect !");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        try {
            Map<String, Object> entity = asStringObjectMap(payload.get("entity"));
            if (entity == null) return ResponseEntity.ok().build();

            String status = (String) entity.get("status");
            String transactionId = (String) entity.get("id");

            if ("approved".equals(status)) {
                Map<String, Object> metadata = asStringObjectMap(entity.get("custom_metadata"));
                if (metadata != null && metadata.containsKey("booking_id")) {
                    Long bookingId = Long.valueOf(metadata.get("booking_id").toString());

                    log.info("🔔 Callback FedaPay reçu pour Booking #{} (TX: {})", bookingId, transactionId);

                    // 1. Marquer succès + enregistrer référence (TX ID)
                    paymentStatusUpdateService.markAsSuccessWithReference(bookingId, transactionId);

                    // 2. Confirmer métier
                    paymentConfirmationService.confirmPayment(transactionId);
                }
            }
            return ResponseEntity.ok().build();

        } catch (Exception e) {
            log.error("💥 Erreur Webhook FedaPay: {}", e.getMessage());
            return ResponseEntity.internalServerError().build();
        }
    }

    private boolean secureEquals(String expected, String provided) {
        if (expected == null || provided == null) return false;
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8),
                provided.getBytes(StandardCharsets.UTF_8));
    }

    private Map<String, Object> asStringObjectMap(Object source) {
        if (!(source instanceof Map<?, ?> rawMap)) return null;
        return rawMap.entrySet().stream()
                .filter(entry -> entry.getKey() instanceof String)
                .collect(java.util.stream.Collectors.toMap(
                        entry -> (String) entry.getKey(),
                        Map.Entry::getValue));
    }
}
