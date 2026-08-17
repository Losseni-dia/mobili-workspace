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

    /** "sandbox" ou "live" — doit correspondre au type de clé fournie (voir application.yml). */
    @Value("${fedapay.environment:sandbox}")
    private String environment;

    public record FedaPayCheckoutResult(String paymentUrl, String transactionId) {
    }

    /**
     * @param frontendBaseUrl Site web (Angular) — jamais l'API — vers lequel rediriger le
     *                        navigateur après le checkout FedaPay. Voir
     *                        {@link com.mobili.backend.module.payment.service.FrontendReturnUrlResolver}.
     */
    public FedaPayCheckoutResult createPaymentSession(double amount, String customerEmail, Long bookingId,
            String frontendBaseUrl) {

        try {
            FedaPay.setApiKey(secretKey.trim());
            // .intern() est indispensable : le SDK FedaPay compare la valeur avec == (pas
            // .equals()) en interne (voir FedaPay.setEnvironement décompilé) — un literal Java
            // codé en dur ("sandbox") matche par hasard grâce à l'internement automatique des
            // constantes de compilation, mais une valeur venue de Spring (@Value) est un nouvel
            // objet String jamais == à la constante du SDK : l'appel échoue alors silencieusement
            // (exception avalée par le catch ci-dessous), laissant l'environnement à null, ce qui
            // fait planter tout appel réel avec NullPointerException("FedaPay environement can't
            // be null").
            FedaPay.setEnvironement(environment.trim().intern());
        } catch (Exception e) {
            // Ne PAS avaler silencieusement : sans environnement configuré, FedaPay.environement
            // reste null et le SDK lève NullPointerException("FedaPay environement can't be
            // null") au premier appel réel (Transaction.create) — remonté ci-dessous comme
            // "Échec FedaPay", jamais un défaut silencieux vers sandbox.
            log.error("💥 Échec configuration environnement FedaPay ({}) : {}", environment, e.getMessage());
            throw new RuntimeException("Échec configuration FedaPay : " + e.getMessage());
        }

        try {
            log.info("🚀 Création transaction pour Booking #{}", bookingId);

            Map<String, Object> params = new HashMap<>();
            params.put("description", "Ticket Mobili #" + bookingId);
            params.put("amount", (int) amount);
            params.put("currency", Map.of("iso", "XOF"));
            // Retour navigateur après paiement : doit pointer vers la page Angular
            // /payment/success (PaymentSuccessComponent lit ?id=), pas vers l'API — l'ancienne
            // URL (api.my-mobili.com/v1/payments/callback) ne correspondait d'ailleurs à aucun
            // endpoint existant (le vrai webhook est /v1/payments/fedapay/callback, configuré
            // séparément côté dashboard FedaPay, sans rapport avec ce paramètre).
            // provider=FEDAPAY : la page /payment/success (Angular) doit savoir quel gateway
            // vérifier, sinon elle appelle verifyFedaPayPayment() même pour un paiement Stripe.
            params.put("callback_url", frontendBaseUrl + "/payment/success?id=" + bookingId + "&provider=FEDAPAY");

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
        FedaPay.setEnvironement(environment.trim().intern());
    }

    /**
     * Remboursement FedaPay : LIMITATION CONNUE côté FedaPay, pas une implémentation
     * manquante côté MOBILI. Vérifié sur leur documentation officielle
     * (docs-v1.fedapay.com/payments/refunding, docs.fedapay.com/dashboard/fr/refunds-fr) :
     * FedaPay n'expose aucune route API de remboursement. Les remboursements ne sont
     * possibles que manuellement, depuis le dashboard marchand FedaPay, et uniquement pour
     * les paiements MTN Mobile Money au statut "Approved". Rien à implémenter côté MOBILI
     * tant que FedaPay n'ajoute pas cette fonctionnalité à son SDK/API.
     */
    public String refund(String transactionId) {
        throw new UnsupportedOperationException(
                "FedaPay ne propose pas de remboursement via API (uniquement depuis le dashboard marchand FedaPay, MTN Mobile Money uniquement). Traitez ce remboursement manuellement sur dashboard.fedapay.com.");
    }

    private static boolean isApprovedOrTransferred(String status) {
        if (status == null) {
            return false;
        }
        return "approved".equals(status) || "transferred".equals(status);
    }
}