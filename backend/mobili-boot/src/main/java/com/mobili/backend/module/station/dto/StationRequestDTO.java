package com.mobili.backend.module.station.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class StationRequestDTO {

    @NotBlank(message = "Le nom de la gare est obligatoire")
    private String name;

    @NotBlank(message = "La ville est obligatoire")
    private String city;

    private Boolean active;

     @NotBlank(message = "Le mot de passe est obligatoire")
    @Size(min = 6, message = "Le mot de passe doit faire au moins 6 caractères")
    private String password;
}
