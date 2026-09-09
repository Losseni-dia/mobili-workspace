package com.mobili.backend.module.admin.dto;

import java.util.List;

public record AdminCityApplyResponse(int appliedCount, List<String> appliedCityNames) {
}
