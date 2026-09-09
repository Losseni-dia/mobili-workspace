package com.mobili.backend.module.admin.dto;

import java.util.List;

public record GeocodingApplyResponse(int appliedCount, List<String> appliedCityLabels) {
}
