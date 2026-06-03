package com.mobili.backend.module.user.dto;

import lombok.Data;

/**
 * Champs du profil covoiturage modifiables par le conducteur lui-même.
 * Le statut KYC et les documents CNI ne sont pas modifiables ici (réservé à l'admin).
 */
@Data
public class UpdateCovoiturageProfileDTO {
    private String vehicleBrand;
    private String vehiclePlate;
    private String vehicleColor;
    private String greyCardNumber;
}
