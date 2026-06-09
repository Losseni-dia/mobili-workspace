package com.mobili.backend.module.partner.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

// PartnerChauffeurUpdateRequest.java
public record PartnerChauffeurUpdateRequest(
        @NotBlank @Size(max = 100) String firstname,
        @NotBlank @Size(max = 100) String lastname,
        @Size(max = 20) String phone,
        @Email @Size(max = 255) String email,
        @Size(min = 8, max = 120) String password) {
}
