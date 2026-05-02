package com.mobili.backend.module.trip.dto;

import java.time.LocalDateTime;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TripStopResponseDTO {
    private int stopIndex;
    private String cityLabel;
    private LocalDateTime plannedDepartureAt;
}
