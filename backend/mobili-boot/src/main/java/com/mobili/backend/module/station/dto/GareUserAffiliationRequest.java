package com.mobili.backend.module.station.dto;

import jakarta.validation.constraints.NotNull;

public record GareUserAffiliationRequest(@NotNull Long stationId) {
}