package com.mobili.backend.module.admin.dto;

/**
 * Raccourci admin : compte créé par l’inscription chauffeur covoiturage (particulier / pool),
 * @see com.mobili.backend.module.user.entity.User#getCovoiturageSoloProfile
 */
public record CovoiturageSoloDriverAdminItem(
        Long id,
        String firstname,
        String lastname,
        String email,
        /** Valeur de {@link com.mobili.backend.module.user.role.CovoiturageKycStatus} ou {@code null}. */
        String covoiturageKycStatus,
        boolean enabled,
        String covoiturageDriverPhotoUrl) {
}
