package com.mobili.backend.module.station.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GarePreviewResponse {
    private String partnerName;
    private Long partnerId;
    private List<StationOption> stations;

    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    public static class StationOption {
        private Long id;
        private String name;
        private String city;
    }
}
