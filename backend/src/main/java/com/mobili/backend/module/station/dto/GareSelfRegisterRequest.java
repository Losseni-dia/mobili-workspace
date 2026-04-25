package com.mobili.backend.module.station.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class GareSelfRegisterRequest {

    @NotBlank(message = "Le code compagnie est obligatoire")
    private String partnerCode;

    /** Si renseigné, rattache l’utilisateur à cette gare (doit appartenir au partenaire). */
    private Long stationId;

    private String newStationName;
    private String newStationCity;

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
