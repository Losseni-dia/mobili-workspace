package com.mobili.backend.module.trip.dto;

import jakarta.validation.constraints.*;

public record TripRatingRequest(
        @NotNull @Min(1) @Max(5) Short note,

        @Size(max = 500) String comment) {
}
