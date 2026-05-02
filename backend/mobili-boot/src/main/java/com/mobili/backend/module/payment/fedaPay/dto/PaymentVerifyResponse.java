package com.mobili.backend.module.payment.fedaPay.dto;

/**
 * Résultat d'une vérification FedaPay après retour utilisateur (complète le webhook).
 */
public record PaymentVerifyResponse(boolean confirmed, String status) {
}
