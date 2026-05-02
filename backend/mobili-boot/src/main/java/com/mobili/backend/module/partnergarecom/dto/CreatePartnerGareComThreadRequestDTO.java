package com.mobili.backend.module.partnergarecom.dto;

import java.util.List;

import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadScope;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CreatePartnerGareComThreadRequestDTO {
    @NotNull
    private PartnerGareComThreadScope scope;

    @NotBlank
    @Size(max = 200)
    private String title;

    /** Requis si scope = TARGETED : au moins une gare de la compagnie. */
    private List<Long> stationIds;

    @NotBlank
    @Size(max = 4000)
    private String firstMessage;
}
