package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;
import java.util.Set;

public record AdminBookingListItemResponse(
        Long id,
        String reference,
        String customerName,
        String route,
        String partnerName,
        String stationName,
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
        String status,
        /** Tous les numéros de sièges réservés à l'origine — voir BookingResponseDTO.seatNumbers
         *  (même convention côté partenaire, BookingMapper). */
        Set<String> seatNumbers,
        /** Sous-ensemble de seatNumbers dont le ticket a été annulé individuellement — reste
         *  affiché (barré/grisé), jamais retiré de la liste. Même convention que
         *  BookingResponseDTO.cancelledSeatNumbers. */
        Set<String> cancelledSeatNumbers) {
}