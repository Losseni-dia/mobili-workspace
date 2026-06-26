package com.mobili.backend.module.admincom.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CreateAdminComThreadRequest {

    @NotBlank
    @Size(max = 300)
    private String subject;

    @NotNull
    private Long partnerUserId;

    /**
     * PARTNER | COVOITURAGE | SUPPORT
     * Si null, le service le déduit automatiquement depuis le profil de
     * l'utilisateur.
     */
    private String type;

    @NotBlank
    @Size(max = 4000)
    private String firstMessage;
}