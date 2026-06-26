package com.mobili.backend.module.user.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * Dossier conducteur covoiturage soumis par un utilisateur déjà inscrit
 * (compte voyageur existant) qui souhaite devenir conducteur — par opposition
 * à {@link RegisterCarpoolChauffeurDTO} qui crée un tout nouveau compte.
 */
@Data
public class ApplyCovoiturageDriverDTO {

    /** Date de fin de validité de la pièce d'identité (doit être dans le futur). */
    @NotNull(message = "La date de fin de validité de la pièce d'identité est obligatoire")
    @Future(message = "La pièce d'identité doit être encore valide (date de fin dans le futur)")
    private LocalDate idValidUntil;

    @NotBlank(message = "La marque du véhicule est obligatoire")
    @Size(max = 80)
    private String vehicleBrand;

    @NotBlank(message = "L'immatriculation est obligatoire")
    @Size(max = 32)
    private String vehiclePlate;

    @NotBlank(message = "La couleur du véhicule est obligatoire")
    @Size(max = 40)
    private String vehicleColor;

    @NotBlank(message = "Le numéro de carte grise est obligatoire")
    @Size(max = 64)
    private String greyCardNumber;
}
