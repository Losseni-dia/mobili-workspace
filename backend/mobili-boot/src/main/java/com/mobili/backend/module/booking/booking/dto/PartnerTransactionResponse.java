package com.mobili.backend.module.booking.booking.dto;

import java.time.LocalDateTime;

/**
 * Une ligne = une réservation payée sur un trajet de CE partenaire. Ne contient JAMAIS le
 * forfait client (booking.serviceFee) : ce montant n'appartient jamais à la compagnie, il ne
 * doit donc apparaître nulle part côté partenaire, même à titre informatif — seul ce qui la
 * concerne réellement (ses ventes, la commission prélevée dessus, son net) est exposé.
 */
public record PartnerTransactionResponse(
        Long bookingId,
        String reference,
        LocalDateTime date,
        /** Date de départ du voyage — distincte de date (date de réservation), voir
         *  PartnerTicketResponse.departureDateTime pour la justification. */
        LocalDateTime departureDateTime,
        String route,
        String stationName,
        /** Somme des prix de tickets + bagages — la vente brute de la compagnie, jamais le forfait. */
        Double grossAmount,
        /** Commission totale prélevée par Mobili sur cette réservation. */
        Integer commissionTotal,
        /** Ce qui revient réellement à la compagnie : grossAmount - commissionTotal. */
        Double companyNet,
        String status) {
}
