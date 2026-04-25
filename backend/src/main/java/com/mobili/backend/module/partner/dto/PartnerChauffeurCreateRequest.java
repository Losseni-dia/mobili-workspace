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
        @NotBlank @Email @Size(max = 255) String email,
        @NotBlank @Size(min = 2, max = 80) String login,
        @NotBlank @Size(min = 8, max = 120) String password,
        /** Gare du réseau de la compagnie (optionnel). */
        Long stationId) {
}
