package com.mobili.backend.module.booking.booking.dto;

import java.util.Set;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ManualBlockRequest {
    private Long tripId;
    private Set<String> seatNumbers;
}