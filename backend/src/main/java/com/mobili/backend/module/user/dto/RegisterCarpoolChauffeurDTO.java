package com.mobili.backend.module.user.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterCarpoolChauffeurDTO {

    @NotBlank(message = "Le prénom est obligatoire")
    private String firstname;

    @NotBlank(message = "Le nom est obligatoire")
    private String lastname;

    @NotBlank(message = "Le login est obligatoire")
    private String login;

    @Email(message = "Format d'email invalide")
    @NotBlank(message = "L'email est obligatoire")
    private String email;

    @NotBlank(message = "Le mot de passe est obligatoire")
    @Size(min = 6, message = "Le mot de passe doit faire au moins 6 caractères")
    private String password;

    /** Date de fin de validité de la pièce d’identité (doit être dans le futur). */
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
