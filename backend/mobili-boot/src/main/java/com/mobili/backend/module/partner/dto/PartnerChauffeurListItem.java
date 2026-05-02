package com.mobili.backend.module.partner.dto;

/**
 * Chauffeur salarié (rôle CHAUFFEUR + employeur = compagnie courante), espace partenaire.
 */
public record PartnerChauffeurListItem(
        Long id,
        String firstname,
        String lastname,
        String email,
        boolean enabled,
        Long affiliationStationId,
        String affiliationStationName) {
}
