package com.mobili.backend.module.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;



public record UpdateUserDTO(
    @NotBlank(message = "Le prénom est obligatoire") String firstname,
    @NotBlank(message = "Le nom est obligatoire") String lastname,
    @NotBlank(message = "L'email est obligatoire") @Email String email,
    @NotBlank(message = "Le login est obligatoire") String login,
    String password // Optionnel ici
) {}
