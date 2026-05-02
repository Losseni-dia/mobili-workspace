package com.mobili.backend.module.trip.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TripLegFareRequest {

    @NotNull
    private Integer fromStopIndex;

    @NotNull
    private Integer toStopIndex;

    @NotNull
    @Min(0)
    private Double price;
}
