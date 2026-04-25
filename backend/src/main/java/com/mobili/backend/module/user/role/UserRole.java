package com.mobili.backend.module.user.role;

public enum UserRole {
    USER, // Client de l'application mobile
    PARTNER,
    /** Responsable / équipe d'une gare rattachée à un partenaire (voyages, stats périmètre gare) */
    GARE,
    CHAUFFEUR,
    ADMIN // Super-administrateur (Accès total au dashboard)
}