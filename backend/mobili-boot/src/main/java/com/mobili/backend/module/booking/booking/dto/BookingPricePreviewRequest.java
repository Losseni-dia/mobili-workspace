package com.mobili.backend.module.booking.booking.dto;

import com.mobili.backend.module.pricing.PricingConstants;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * Prévisualisation du prix d'une réservation AVANT paiement — même forme d'entrée que
 * BookingRequestDTO pour ce qui affecte le prix (sièges, segment, bagages, coupon), sans les
 * champs propres à la création réelle (sélections nominatives).
 */
@Data
public class BookingPricePreviewRequest {
    @NotNull(message = "L'ID du voyage est obligatoire")
    private Long tripId;

    @NotNull(message = "Le nombre de places est obligatoire")
    @Min(value = 1)
    @Max(value = PricingConstants.MAX_TICKETS_PER_BOOKING, message = "Maximum "
            + PricingConstants.MAX_TICKETS_PER_BOOKING + " tickets par réservation")
    private Integer numberOfSeats;

    /** Optionnel : 0 = premier arrêt du voyage (défaut). */
    private Integer boardingStopIndex;

    /** Optionnel : terminus (défaut). */
    private Integer alightingStopIndex;

    @Min(0)
    private Integer extraHoldBags;

    private String couponCode;
}
