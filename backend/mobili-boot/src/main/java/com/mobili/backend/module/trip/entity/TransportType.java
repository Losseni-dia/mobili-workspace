package com.mobili.backend.module.trip.entity;

/**
 * Type d’offre : ligne régulière (transport public / partenaire) ou covoiturage.
 */
public enum TransportType {
    /** Transport public / lignes partenaires (défaut). */
    PUBLIC,
    /** Covoiturage. */
    COVOITURAGE
}
