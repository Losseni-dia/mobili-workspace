package com.mobili.backend.module.admin.dto;

/**
 * Réponse de POST /admin/bookings/{bookingId}/cancel.
 *
 * BookingService.cancelBooking() (inchangée, déjà testée) ne renvoie rien et
 * ne déclenche un remboursement automatique que pour Stripe — jamais pour
 * FedaPay (pas d'API de remboursement chez ce provider). Ce DTO permet à
 * l'UI (MobiliPro) de savoir précisément ce qui vient de se passer, avant
 * même que le paiement lié ne soit modifié par l'annulation.
 */
public record CancelBookingResponse(
        Long bookingId,
        String provider,
        boolean autoRefunded,
        String message,
        /** FCFA, jamais le forfait client — null si aucun paiement réussi trouvé. */
        Double refundedAmount) {
}
