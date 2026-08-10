package com.mobili.backend.module.claim.enums;

/** Statut de traitement d'une réclamation — transitions libres, décidées par l'admin. */
public enum ClaimStatus {
    RECEIVED,
    IN_PROGRESS,
    RESOLVED,
    REJECTED
}
