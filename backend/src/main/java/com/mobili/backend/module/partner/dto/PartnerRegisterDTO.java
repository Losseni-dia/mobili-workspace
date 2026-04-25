package com.mobili.backend.module.partner.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class PartnerRegisterDTO {
    @NotBlank(message = "Le nom de la société est obligatoire")
    private String name;

    @Email(message = "Format d'email invalide")
    @NotBlank(message = "L'email est obligatoire")
    private String email;

    @NotBlank(message = "Le numéro de téléphone est obligatoire")
    private String phone;

    private String businessNumber;
    // Le logo sera géré à part via le MultipartFile
}