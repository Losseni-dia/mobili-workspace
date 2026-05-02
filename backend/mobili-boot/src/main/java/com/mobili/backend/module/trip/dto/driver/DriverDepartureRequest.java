package com.mobili.backend.module.trip.dto.driver;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class DriverDepartureRequest {

    @NotNull
    @Min(0)
    private Integer stopIndex;
}
