package com.mobili.backend.module.admin.dto;

import java.util.List;

/**
 * Fiche admin utilisateur : rattachement compagnie / gare pour GARE & chauffeurs, flag covo particulier.
 */
public record UserAdminResponse(
        Long id,
        String firstname,
        String lastname,
        String email,
        List<String> roles,
        boolean enabled,
        /** Dirigeant : nom commercial du partenaire lié en tant que propriétaire. */
        String partnerName,
        /** Inscription chauffeur covoiturage particulier (hors compagnie). */
        Boolean covoiturageSoloProfile,
        /**
         * Compagnie d’emploi : {@code station.partner} si compte gare, sinon {@code user.partner} (dirigeant, chauffeur
         * lié, etc.).
         */
        String linkedCompanyName,
        /** Nom de la gare si le compte est rattaché à une gare. */
        String stationName,
        /**
         * ID fiche compagnie employeuse (chauffeur / salarié), distinct de la fiche partenaire « propriétaire »
         * ({@link #partnerName}).
         */
        Long employerPartnerId) {
}