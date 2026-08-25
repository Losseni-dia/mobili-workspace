package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;

/**
 * Une ligne = une réservation payée (CONFIRMED/OFFLINE_SALE) — décompose ce qui a été
 * réellement encaissé entre : ce qui revient à Mobili (serviceFee, jamais reversé à la
 * compagnie), ce que Mobili prélève sur la compagnie (commissionTotal), et ce qui revient
 * réellement à la compagnie (companyNet). serviceFee/commissionTotal valent 0 sur les
 * réservations antérieures à ce chantier (pas de recalcul rétroactif).
 */
public record AdminTransactionResponse(
        Long bookingId,
        String reference,
        LocalDateTime date,
        String customerName,
        String route,
        Long companyId,
        String companyName,
        /** Gare de départ du trajet (null si covoiturage/aucune gare associée). */
        Long stationId,
        String stationName,
        /** Somme des prix de tickets seule (hors forfait, hors bagages). */
        Double ticketsAmount,
        /** Frais de service Mobili (forfait client) — jamais reversé à la compagnie. */
        Integer serviceFee,
        Double luggageFee,
        /** Commission totale prélevée sur la compagnie pour cette réservation. */
        Integer commissionTotal,
        /** Ce qui revient réellement à la compagnie : ticketsAmount + luggageFee - commissionTotal. */
        Double companyNet,
        /** Montant total payé par le passager (ticketsAmount + serviceFee + luggageFee). */
        Double totalPrice,
        String status) {
}
