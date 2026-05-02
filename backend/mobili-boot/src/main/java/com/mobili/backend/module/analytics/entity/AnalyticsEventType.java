package com.mobili.backend.module.analytics.entity;

/**
 * Types d'événements produit (pas de PII : payload JSON technique uniquement).
 */
public enum AnalyticsEventType {
    FAILED_LOGIN,
    /** Recherche trajets avec critères et zéro résultat. */
    SEARCH_NO_RESULT,
    /** Réservation créée (statut PENDING). */
    BOOKING_CREATED,
    /** Paiement confirmé (portefeuille ou FedaPay). */
    BOOKING_PAID,
    /** Nouveau trajet publié par un partenaire. */
    TRIP_PUBLISHED,
    /** Exception non gérée côté API (5xx). */
    SERVER_ERROR
}
