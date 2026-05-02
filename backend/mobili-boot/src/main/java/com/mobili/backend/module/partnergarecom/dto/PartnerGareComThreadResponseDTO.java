package com.mobili.backend.module.partnergarecom.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadScope;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class PartnerGareComThreadResponseDTO {
    Long id;
    PartnerGareComThreadScope scope;
    String title;
    LocalDateTime lastActivityAt;
    /** Vide si scope = ALL. Sinon identifiants des gares ciblées. */
    List<Long> stationIds;
    List<String> stationLabels;
}
