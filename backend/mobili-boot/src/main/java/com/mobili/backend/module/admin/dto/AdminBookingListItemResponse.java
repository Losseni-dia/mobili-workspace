package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;

public record AdminBookingListItemResponse(
        Long id,
        String reference,
        String customerName,
        String route,
        String partnerName,
        LocalDateTime bookingDate,
        /** Date de départ du voyage — distincte de bookingDate (date de réservation), voir
         *  PartnerTicketResponse.departureDateTime pour la justification. */
        LocalDateTime departureDateTime,
        Integer numberOfSeats,
        /** Montant de vente initial, figé — n'exclut PAS les tickets annulés depuis. Ne jamais
         *  l'utiliser seul pour un affichage : préférer {@link #amount()}. */
        Double totalPrice,
        /** Montant réellement dû aujourd'hui (ticketsAmount + serviceFee + luggageFee des
         *  tickets encore actifs) — se réduit après une annulation partielle, contrairement à
         *  {@link #totalPrice()}. Champ à afficher côté admin. */
        Double amount,
        String status) {
}