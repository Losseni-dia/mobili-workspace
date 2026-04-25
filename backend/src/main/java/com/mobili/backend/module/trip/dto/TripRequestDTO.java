package com.mobili.backend.module.trip.dto;

import java.time.LocalDateTime;

import com.mobili.backend.module.trip.entity.TransportType;
import com.mobili.backend.module.trip.entity.VehicleType; // Import local

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TripRequestDTO {

    private Long id;

    @NotNull(message = "L'ID du partenaire est obligatoire")
    private Long partnerId;

    /** Rattache le voyage à une gare (dirigeant) ; ignoré / forcé côté serveur pour un compte gare. */
    private Long stationId;

    @NotBlank(message = "La ville de départ est obligatoire")
    private String departureCity;

    @NotBlank(message = "La ville d'arrivée est obligatoire")
    private String arrivalCity;

    // Harmonisé avec le front-end et l'entité
    @NotBlank(message = "Le lieu d'embarquement est obligatoire")
    private String boardingPoint;

    @NotBlank(message = "Le numéro de plaque est obligatoire")
    private String vehiculePlateNumber;

    @NotNull(message = "Le type de véhicule est obligatoire")
    private VehicleType vehicleType;

    /** PUBLIC = transport public / ligne ; COVOITURAGE = covoiturage. Défaut géré côté serveur si absent. */
    private TransportType transportType;

    @NotNull(message = "La date et l'heure de départ sont obligatoires")
    private LocalDateTime departureDateTime;

    @NotNull(message = "Le prix est obligatoire")
    @Min(value = 0, message = "Le prix ne peut pas être négatif")
    private Double price;

    /**
     * Prix trajet complet (1er → dernier arrêt). Obligatoire s’il y a au moins 2 tronçons
     * ({@code legFares}) : peut différer de la somme des tronçons.
     */
    private Double originDestinationPrice;

    @NotNull(message = "Le nombre de places est obligatoire")
    @Min(value = 1, message = "Il doit y avoir au moins une place disponible")
    private Integer totalSeats;

    @NotNull(message = "Le nombre de places disponibles est obligatoire")
    @Min(value = 1, message = "Il doit y avoir au moins une place disponible")
    private Integer availableSeats;

    // Contiendra les villes d'arrêt (stops)
    private String moreInfo;

    /**
     * Tarifs par tronçon consécutif (0→1, 1→2, …). {@code null} = ne pas modifier les tarifs existants
     * (mise à jour). Liste vide = supprimer les tarifs tronçon (retour au prorata sur {@link #price}).
     */
    @Valid
    private List<TripLegFareRequest> legFares;

    /**
     * Chauffeur salarié désigné pour ce service. À la <strong>mise à jour</strong> : {@code null} = ne pas modifier
     * l’affectation existante ; {@code 0} = retirer l’affectation. À la création : {@code null} ou {@code 0} = aucun
     * chauffeur assigné.
     */
    private Long assignedChauffeurId;

    @Min(0)
    private Integer includedCabinBagsPerPassenger;

    @Min(0)
    private Integer includedHoldBagsPerPassenger;

    @Min(0)
    private Integer maxExtraHoldBagsPerPassenger;

    @Min(0)
    private Double extraHoldBagPrice;
}