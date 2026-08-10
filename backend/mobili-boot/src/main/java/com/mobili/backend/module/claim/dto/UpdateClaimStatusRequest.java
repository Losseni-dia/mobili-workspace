package com.mobili.backend.module.claim.dto;

import com.mobili.backend.module.claim.enums.ClaimStatus;

/**
 * adminNote : note interne, jamais renvoyée au passager. resolutionMessage : message de
 * clôture visible par le passager (aussi utilisé comme corps de la notification envoyée à
 * la clôture) — pertinent seulement quand status vaut RESOLVED ou REJECTED.
 */
public record UpdateClaimStatusRequest(ClaimStatus status, String adminNote, String resolutionMessage) {
}
