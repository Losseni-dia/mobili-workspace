package com.mobili.backend.module.user.role;

/**
 * Validation des pièces d’identité pour les chauffeurs covoiturage.
 */
public enum CovoiturageKycStatus {
    /** Voyageur classique, partenaire, ou chauffeur sans dossier covoiturage. */
    NONE,
    /** Dossier déposé à l’inscription, en attente de traitement. */
    PENDING,
    APPROVED,
    REJECTED,
    /** Pièce d’identité arrivée à expiration (à renouveler). */
    EXPIRED
}
