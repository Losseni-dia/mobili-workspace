package com.mobili.backend.module.station.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class StationRequestDTO {

    @NotBlank(message = "Le nom de la gare est obligatoire")
    private String name;

    @NotBlank(message = "La ville est obligatoire")
    private String city;

    private Boolean active;
}
