package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.mobili.backend.module.analytics.entity.AnalyticsEventType;

public record AnalyticsSummaryResponse(
        LocalDateTime from,
        int days,
        List<CountByType> byType) {

    public record CountByType(AnalyticsEventType type, long count) {
    }
}
