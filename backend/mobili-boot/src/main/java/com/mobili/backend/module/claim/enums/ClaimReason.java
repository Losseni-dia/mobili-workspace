package com.mobili.backend.module.claim.enums;

/**
 * Motifs de réclamation. Comportement associé (comme CouponType/PaymentProvider) plutôt
 * qu'un champ booléen séparé à maintenir en double quelque part côté service.
 *
 * Ajouter un motif : une valeur ici + son cas dans requiresBooking() — jamais de migration
 * de schéma, les champs propres à un motif vivent dans Claim.detailsJson.
 */
public enum ClaimReason {
    REFUND_REQUEST,
    CANCELLATION,
    DELAY,
    DRIVER_ISSUE,
    LOST_ITEM,
    OTHER;

    /**
     * Un bookingId est-il obligatoire pour ce motif ? Source de vérité côté backend —
     * la config de présentation côté app (claim_reasons.dart) ne fait que refléter ce
     * comportement pour l'UI, elle ne le duplique pas en tant que règle métier.
     */
    public boolean requiresBooking() {
        return switch (this) {
            case REFUND_REQUEST, CANCELLATION, DELAY, DRIVER_ISSUE -> true;
            case LOST_ITEM, OTHER -> false;
        };
    }
}
