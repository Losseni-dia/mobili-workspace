package com.mobili.backend.module.claim.dto;

import com.mobili.backend.module.claim.enums.ClaimStatus;

import jakarta.validation.constraints.NotNull;

/**
 * adminNote : note interne, jamais renvoyée au passager. resolutionMessage : message de
 * clôture visible par le passager (aussi utilisé comme corps de la notification envoyée à
 * la clôture) — pertinent seulement quand status vaut RESOLVED ou REJECTED.
 *
 * @NotNull sur status (AUDIT-MOBILI.md §1.1) : c'était auparavant vérifié uniquement dans
 * ClaimService.updateStatus (status == null) — remonté ici en validation Bean pour un 400
 * cohérent (MOB-003) avant même d'atteindre le service.
 */
public record UpdateClaimStatusRequest(
        @NotNull(message = "Le nouveau statut est obligatoire.") ClaimStatus status,
        String adminNote,
        String resolutionMessage) {
}
