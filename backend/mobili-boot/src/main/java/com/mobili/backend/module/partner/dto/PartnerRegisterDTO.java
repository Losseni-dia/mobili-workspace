package com.mobili.backend.module.partner.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class PartnerRegisterDTO {
    @NotBlank(message = "Le nom de la société est obligatoire")
    private String name;

    @Email(message = "Format d'email invalide")
    private String email;

    @NotBlank(message = "Le numéro de téléphone est obligatoire")
    private String phone;

    private String businessNumber;

    /** Pays de la société — voir Country. Obligatoire pour les nouvelles inscriptions publiques
     *  (RegisterCompanyPublicDTO), résolu et assigné dans PartnerService.createPartnerForOwner
     *  (pas mappé automatiquement par MapStruct : Long -> entité Country). */
    private Long countryId;
    // Le logo sera géré à part via le MultipartFile
}