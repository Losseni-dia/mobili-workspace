package com.mobili.backend.module.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * Inscription publique « dirigeant société » : représentant + société en une fois,
 * sans passer par un compte voyageur séparé.
 */
@Data
public class RegisterCompanyPublicDTO {

    @NotBlank(message = "Le prénom du responsable est obligatoire")
    private String firstname;

    @NotBlank(message = "Le nom du responsable est obligatoire")
    private String lastname;

    @NotBlank(message = "Le login est obligatoire")
    private String login;

    @Email(message = "Format d’email invalide pour le dirigeant")
    @NotBlank(message = "L’email du dirigeant est obligatoire")
    private String email;

    @NotBlank(message = "Le mot de passe est obligatoire")
    @Size(min = 6, message = "Le mot de passe doit faire au moins 6 caractères")
    private String password;

    @NotBlank(message = "Le nom de la société est obligatoire")
    private String companyName;

    @Email(message = "Format d’email invalide pour la société")
    @NotBlank(message = "L’email officiel de la société est obligatoire")
    private String companyEmail;

    @NotBlank(message = "Le téléphone de la société est obligatoire")
    private String companyPhone;

    /** RCC / N° contribuable / ICE selon pays — optionnel. */
    private String businessNumber;
}
