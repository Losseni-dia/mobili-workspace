package com.mobili.backend.module.booking.booking.entity;

import lombok.Getter;

@Getter
public enum BookingStatus {
    PENDING("En attente"),
    CONFIRMED("Confirmé"),
    CANCELLED("Annulé"),
    COMPLETED("Terminé"),
    OFFLINE_SALE("Achat physique"),
    PENDING_DRIVER_APPROVAL ( "En attente d'approbation du chauffeur" ), // covoiturage : demande envoyée, en attente du chauffeur
    AWAITING_PAYMENT ( "En attente de paiement" ),      // covoiturage : chauffeur a accepté, 30 min pour payer
    REJECTED_BY_DRIVER ( "Rejeté par le chauffeur" ),    // covoiturage : chauffeur a refusé
    EXPIRED("Expiré");              // covoiturage : 24h sans réponse, ou 30 min sans paiement après acceptation


    private final String label;

    BookingStatus(String label) {
        this.label = label;
    }
}