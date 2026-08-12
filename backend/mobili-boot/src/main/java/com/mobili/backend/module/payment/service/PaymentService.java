package com.mobili.backend.module.payment.service;

import com.mobili.backend.module.payment.dto.RefundResult;
import com.mobili.backend.module.payment.enums.PaymentProvider;

public interface PaymentService {

    /**
     * Crée une session de paiement chez le fournisseur.
     * @param amount Montant en unités réelles (ex: XOF ou EUR réel)
     * @return URL de paiement
     */
    String createPaymentSession(Long bookingId, Long amount, String currency, String customerEmail);

    /**
     * Demande un remboursement au fournisseur.
     * @param externalReference Référence de la transaction
     * @return Résultat du remboursement
     */
    RefundResult refundPayment(String externalReference);

    /**
     * Remboursement partiel — montant en FCFA, jamais le forfait client (frais
     * irrécupérables côté agrégateur, jamais reversés). Implémentation par défaut : les
     * providers qui ne savent pas faire de remboursement partiel (ex. FedaPay, sans API de
     * remboursement du tout — voir FedaPayPaymentService, jamais modifié pour ce chantier)
     * retombent simplement sur le comportement existant, montant ignoré.
     */
    default RefundResult refundPayment(String externalReference, Long amount) {
        return refundPayment(externalReference);
    }

    /**
     * Retourne le provider supporté par cette implémentation.
     */
    PaymentProvider getPaymentProvider();
}
