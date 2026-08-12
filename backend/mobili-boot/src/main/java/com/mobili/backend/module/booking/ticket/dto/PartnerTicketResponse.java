package com.mobili.backend.module.booking.ticket.dto;

import java.time.LocalDateTime;

public record PartnerTicketResponse(
        Long id,
        String ticketNumber,
        String passengerName,
        String route,
        String stationName,
        LocalDateTime bookingDate,
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