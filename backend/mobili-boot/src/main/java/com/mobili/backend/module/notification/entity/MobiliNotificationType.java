package com.mobili.backend.module.notification.entity;

/**
 * Types de messages dans la boîte métier (distinct des toasts UI).
 */
public enum MobiliNotificationType {
    /** Billet issu d’une réservation payée. */
    TICKET_ISSUED,
    /** Annonce / retard publié sur le canal d’un voyage. */
    TRIP_CHANNEL_MESSAGE,
    /** Nouvelle réservation payée : destiné au compte partenaire (propriétaire). */
    PARTNER_NEW_BOOKING,
    /**
     * Nouvelle réservation payée sur un voyage rattaché à la gare : destiné aux comptes
     * {@link com.mobili.backend.module.user.role.UserRole#GARE} de cette station.
     */
    GARE_STATION_NEW_BOOKING,
    /** Message (fil) entre dirigeant et responsables gare. */
    PARTNER_GARE_COM_MESSAGE,
    /** CNI covoiturage : expiration dans les 30 prochains jours. */
    COV_KYC_EXPIRING_SOON,
    /** CNI covoiturage : date de validité dépassée. */
    COV_KYC_EXPIRED,
    /** Annonce / information envoyée par l’équipe Mobili (espace admin) au dirigeant partenaire. */
    MOBILI_ADMIN_INFO_PARTNER,
    PARTNER_SUBMISSION_PENDING,
            
    /** Réservation annulée. */
    BOOKING_CANCELLED,
            /** Compagnie approuvée par l'admin. */
    PARTNER_APPROVED,
    /** Compagnie rejetée par l'admin. */
    PARTNER_REJECTED,
    /** Dossier KYC covoiturage approuvé par l'admin. */
    COV_KYC_APPROVED,
    /** Dossier KYC covoiturage rejeté par l'admin. */
   /** Dossier KYC covoiturage rejeté par l'admin. */
    COV_KYC_REJECTED,
    /** Nouvelle demande de réservation covoiturage : destiné au conducteur organisateur. */
    COVOITURAGE_BOOKING_REQUEST,
    /** Le conducteur a accepté la demande : destiné au passager (30 min pour payer). */
    COVOITURAGE_BOOKING_ACCEPTED,
    /** Le conducteur a refusé la demande : destiné au passager. */
    COVOITURAGE_BOOKING_REJECTED,
    /** La demande a expiré (24h sans réponse du conducteur) : destiné au passager. */
    COVOITURAGE_BOOKING_NO_RESPONSE,
    /** Le délai de paiement de 30 min après acceptation est dépassé : destiné au passager. */
    COVOITURAGE_BOOKING_PAYMENT_EXPIRED,

    /** Nouvelle réclamation soumise par un passager : destiné aux comptes admin. */
    CLAIM_SUBMITTED,
    /** Réclamation passée à RESOLVED ou REJECTED : destiné au passager auteur. */
    CLAIM_STATUS_UPDATED,

}
