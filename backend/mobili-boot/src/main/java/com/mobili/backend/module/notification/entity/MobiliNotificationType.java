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
    MOBILI_ADMIN_INFO_PARTNER
}
