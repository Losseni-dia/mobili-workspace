package com.mobili.backend.module.partner.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Inscription d’un chauffeur société par le dirigeant (espace partenaire), sans passage par l’admin.
 */
public record PartnerChauffeurCreateRequest(
                @NotBlank @Size(max = 100) String firstname,
                @NotBlank @Size(max = 100) String lastname,
                @Size(max = 255) @Email String email, // ← optionnel
                @NotBlank @Size(min = 8, max = 20) String phone, // ← obligatoire
                @NotBlank @Size(min = 2, max = 80) String login,
                @NotBlank @Size(min = 8, max = 120) String password,
                Long stationId) {
}
