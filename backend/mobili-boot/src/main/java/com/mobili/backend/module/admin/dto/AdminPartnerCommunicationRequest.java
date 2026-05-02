package com.mobili.backend.module.admin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Demande d’envoi d’une communication à l’inbox des comptes dirigeants (propriétaire partenaire). gdgdgdg
 */
@Data
@NoArgsConstructor
public class AdminPartnerCommunicationRequest {

    @NotBlank
    @Size(max = 300)
    private String title;

    @NotBlank
    @Size(max = 2000)
    private String body;

    /**
     * BROADCAST = selon le segment, tous les partenaires concernés ; PICK = liste explicite d’ID partenaire.
     */
    private AdminPartnerCommunicationTarget target = AdminPartnerCommunicationTarget.BROADCAST;

    /**
     * Filtre si {@link #target} est BROADCAST.
     */
    private AdminPartnerCommunicationSegment segment = AdminPartnerCommunicationSegment.ALL;

    /**
     * Inclut les comptes partenaire désactivés (suspension) dans un envoi BROADCAST. Ignoré en mode PICK
     * (l’admin a choisi explicitement des ID).
     */
    private boolean includeDisabled;

    /**
     * ID partenaires requis si target = PICK.
     */
    private java.util.List<Long> partnerIds;

    public enum AdminPartnerCommunicationTarget {
        BROADCAST,
        PICK
    }

    public enum AdminPartnerCommunicationSegment {
        /** Tous les partenaires avec compte dirigeant. */
        ALL,
        /** Uniquement compagnies / lignes (hors partenaire technique pool covoiturage). */
        COMPANIES,
        /** Uniquement le (ou les) partenaire(s) pool covoiturage particulier. */
        COVOITURAGE_POOL
    }
}
