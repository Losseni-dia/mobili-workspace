package com.mobili.backend.module.booking.ticket.dto;

import java.time.LocalDateTime;

public record PartnerTicketResponse(
        Long id,
        String ticketNumber,
        /** Passager du siège (peut différer du client qui a réservé — voir customerName). */
        String passengerName,
        String route,
        /** Trajet auquel ce ticket appartient — permet de regrouper les tickets par voyage
         *  côté client (ex: écran "Mes gares" mobilipro, GareDetailPage). */
        Long tripId,
        /** Statut de la réservation d'origine (CONFIRMED/OFFLINE_SALE/...) — distinct du statut
         *  du ticket lui-même (VALIDÉ/ANNULÉ/...) : sert à distinguer vente en ligne / guichet. */
        String bookingStatus,
        String stationName,
        LocalDateTime bookingDate,
        /** N° de la réservation d'origine (un même booking peut couvrir plusieurs tickets/sièges). */
        Long bookingId,
        /** Client ayant effectué la réservation (compte connecté), distinct du passager du siège. */
        String customerName,
        /**
         * Part du prix global (transport + forfait client + bagages), pour affichage passager
         * uniquement — jamais côté partenaire (voir grossAmount), qui n'a jamais reçu le
         * forfait dilué dans ce chiffre.
         */
        Double amountPaid,
        /**
         * Vente brute de la compagnie pour CE ticket (transportFare + baggageFee, jamais le
         * forfait client). Null si transportFare est absent (ticket antérieur à la
         * décomposition tarifaire) — le consommateur retombe alors sur amountPaid.
         */
        Double grossAmount,
        String status,
        String seatNumber,
        boolean scanned) {
}