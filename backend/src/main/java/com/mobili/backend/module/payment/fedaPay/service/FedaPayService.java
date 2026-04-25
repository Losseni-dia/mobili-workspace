package com.mobili.backend.module.payment.fedaPay.service;


// On n'importe plus FedaPayException si VS Code ne le voit pas
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.fedapay.model.FedaPay;
import com.fedapay.model.Transaction;

import java.util.HashMap;
import java.util.Map;

@Service
@Slf4j
public class FedaPayService {

    @Value("${FEDAPAY_SECRET_KEY}")
    private String secretKey;

    public record FedaPayCheckoutResult(String paymentUrl, String transactionId) {
    }

    public FedaPayCheckoutResult createPaymentSession(double amount, String customerEmail, Long bookingId) {

        try {
            FedaPay.setApiKey(secretKey.trim());
            // On teste cette syntaxe. Si VS Code souligne encore,
            // regarde dans les suggestions (Ctrl+Espace) après "FedaPay."
            FedaPay.setEnvironement("sandbox");
        } catch (Exception e) {
            log.warn("Tentative de config alternative pour l'environnement...");
            // Option de secours si la première échoue au runtime
        }

        // Si setEnvironment ne marche pas, le SDK utilise la sandbox par défaut
        // ou on peut forcer l'URL si nécessaire. Essayons sans pour voir.

        try {
            log.info("🚀 Création transaction pour Booking #{}", bookingId);

            Map<String, Object> params = new HashMap<>();
            params.put("description", "Ticket Mobili #" + bookingId);
            params.put("amount", (int) amount);
            params.put("currency", Map.of("iso", "XOF"));
            params.put("callback_url", "http://localhost:4200/payment/success?id=" + bookingId);

            // Le SDK attend souvent les métadonnées ainsi :
            Map<String, Object> metadata = new HashMap<>();
            metadata.put("booking_id", bookingId);
            params.put("custom_metadata", metadata);

            params.put("customer", Map.of(
                    "email", customerEmail.trim(),
                    "firstname", "Client",
                    "lastname", "Mobili"));

            // 2. Création de la transaction
            Transaction transaction = Transaction.create(params);
            if (transaction.getId() == null) {
                throw new IllegalStateException("FedaPay: transaction sans id");
            }
            // 3. Lien de paiement
            String link = transaction.generateToken().getSecurePaymentLink();
            return new FedaPayCheckoutResult(link, transaction.getId());

        } catch (Exception e) {
            log.error("💥 Erreur FedaPay : {} - {}", e.getClass().getSimpleName(), e.getMessage());
            throw new RuntimeException("Échec FedaPay : " + e.getMessage());
        }
    }

    /**
     * Indique si la transaction est finalisée côté FedaPay pour émettre les billets.
     * (On n'utilise pas {@link Transaction#wasPaid()} seul : il inclut "refunded".)
     */
    public boolean isTransactionApprovedForBooking(String transactionId) {
        if (transactionId == null || transactionId.isBlank()) {
            return false;
        }
        try {
            applyApiConfig();
            Transaction t = Transaction.retrieve(transactionId);
            if (t == null) {
                return false;
            }
            return isApprovedOrTransferred(t.getStatus());
        } catch (Exception e) {
            log.warn("FedaPay retrieve({}) : {}", transactionId, e.getMessage());
            return false;
        }
    }

    private void applyApiConfig() throws Exception {
        FedaPay.setApiKey(secretKey.trim());
        FedaPay.setEnvironement("sandbox");
    }

    private static boolean isApprovedOrTransferred(String status) {
        if (status == null) {
            return false;
        }
        return "approved".equals(status) || "transferred".equals(status);
    }
}