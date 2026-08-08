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
     * Retourne le provider supporté par cette implémentation.
     */
    PaymentProvider getPaymentProvider();
}
