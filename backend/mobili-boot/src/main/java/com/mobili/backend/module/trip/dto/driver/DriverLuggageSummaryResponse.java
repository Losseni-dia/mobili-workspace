package com.mobili.backend.module.trip.dto.driver;

import lombok.Data;

/** Synthèse bagages pour le conducteur (déclaré vs politique du voyage). */
@Data
public class DriverLuggageSummaryResponse {

    private Integer includedCabinBagsPerPassenger;
    private Integer includedHoldBagsPerPassenger;
    private Integer maxExtraHoldBagsPerPassenger;
    private Double extraHoldBagPrice;

    /** Passagers payants (réservations confirmées / terminées). */
    private int confirmedPassengerSeats;

    /** Bagages soute « gratuits » attendus = places × quota inclus. */
    private int expectedIncludedHoldBags;

    /** Bagages cabine attendus = places × quota cabine. */
    private int expectedIncludedCabinBags;

    /** Total bagages soute supplémentaires réservés (payants). */
    private int totalExtraHoldBagsReserved;

    /** Plafond autorisé pour les supplémentaires sur ce service (si tous les passagers maxent). */
    private int maxPossibleExtraHoldBags;
}
