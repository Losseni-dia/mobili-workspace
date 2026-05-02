package com.mobili.backend.module.station.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class GareUserCreateRequest {

    @NotNull(message = "La gare est obligatoire")
    private Long stationId;

    @NotBlank
    @Size(min = 2, max = 64)
    private String login;

    @NotBlank
    @Email
    private String email;

    @NotBlank
    @Size(min = 6, max = 128)
    private String password;

    @NotBlank
    private String firstname;

    @NotBlank
    private String lastname;
}
