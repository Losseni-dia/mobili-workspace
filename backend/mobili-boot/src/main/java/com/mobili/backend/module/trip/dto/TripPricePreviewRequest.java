package com.mobili.backend.module.trip.dto;

import java.time.LocalDateTime;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class TripPricePreviewRequest {

    @NotBlank
    private String departureCity;

    @NotBlank
    private String arrivalCity;

    /** Villes étapes (CSV), comme {@code TripRequestDTO.moreInfo}. */
    private String moreInfo;

    @NotNull
    @Min(0)
    private Double price;

    @NotNull
    @Min(0)
    private Integer boardingStopIndex;

    @NotNull
    @Min(0)
    private Integer alightingStopIndex;

    /** Pour horaires planifiés des arrêts (optionnel ; défaut : maintenant). */
    private LocalDateTime departureDateTime;

    /** Si renseigné : somme des tronçons consécutifs (même règle qu’à l’enregistrement du voyage). */
    @Valid
    private List<TripLegFareRequest> legFares;

    /**
     * Prix 1er → dernier arrêt : utilisé en prévisualisation quand embarquement=0 et descente=dernier arrêt
     * (même règle qu’à l’enregistrement).
     */
    @Min(0)
    private Double originDestinationPrice;
}
