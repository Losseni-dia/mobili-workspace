package com.mobili.backend.module.partner.dto;

/**
 * Affecte ou retire la gare d’exercice d’un chauffeur salarié ({@code null} = aucune gare).
 */
public record PartnerChauffeurAffiliationRequest(Long stationId) {
}
