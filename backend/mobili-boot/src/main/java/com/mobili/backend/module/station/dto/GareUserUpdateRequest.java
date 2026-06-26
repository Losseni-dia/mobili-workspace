package com.mobili.backend.module.station.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record GareUserUpdateRequest(
                @NotBlank @Size(max = 100) String firstname,
                @NotBlank @Size(max = 100) String lastname,
                @Email @Size(max = 255) String email,
                @Size(max = 20) String phone,
                @Size(min = 6, max = 120) String password) {
}