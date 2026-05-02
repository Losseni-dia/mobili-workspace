package com.mobili.backend.module.trip.dto;

import java.time.LocalDateTime;

import com.mobili.backend.module.trip.entity.VehicleType;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * Création d’offre covoiturage particulier (hors compagnie). Le partenaire technique est
 * attribué côté serveur.
 */
@Data
public class CovoiturageSoloTripRequestDTO {

    @NotBlank(message = "La ville de départ est obligatoire")
    private String departureCity;

    @NotBlank(message = "La ville d'arrivée est obligatoire")
    private String arrivalCity;

    @NotBlank(message = "Le lieu d'embarquement / rendez-vous est obligatoire")
    private String boardingPoint;

    /**
     * Optionnel : sinon reprise de la plaque déclarée à l’inscription covoiturage.
     */
    private String vehiculePlateNumber;

    @NotNull(message = "Le type de véhicule est obligatoire")
    private VehicleType vehicleType;

    @NotNull(message = "La date et l'heure de départ sont obligatoires")
    private LocalDateTime departureDateTime;

    @NotNull(message = "Le prix par place (ou contribution) est obligatoire")
    @Min(value = 0, message = "Le prix ne peut pas être négatif")
    private Double price;

    @NotNull(message = "Le nombre de places est obligatoire")
    @Min(value = 1, message = "Au moins une place")
    private Integer totalSeats;

    /** Villes d’étape optionnelles, virgule (même format que l’espace pro). */
    private String moreInfo;
}
