package com.mobili.backend.module.partner.dto;

import lombok.Data;

@Data
public class PartnerProfileDTO {
    private Long id;
    private String name;
    private String email;
    private String phone;
    private String logoUrl;
    private String businessNumber;
    private boolean enabled;
    /** Code saisi par les gares à l’auto-inscription. */
    private String registrationCode;
    private String approvalStatus;
    private String rejectionReason;
    /** Pays de la société (voir Country) — filtre les villes proposées à la création de gare
     *  (StationService.resolveCity impose la même contrainte côté backend). */
    private Long countryId;
    private String countryName;
}