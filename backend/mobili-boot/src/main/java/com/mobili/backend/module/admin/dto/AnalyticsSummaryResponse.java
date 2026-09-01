package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.mobili.backend.module.analytics.entity.AnalyticsEventType;

public record AnalyticsSummaryResponse(
        LocalDateTime from,
        int days,
        List<CountByType> byType,
        /** Mêmes types, sur la période précédente de même durée immédiatement avant `from` —
         *  sert à afficher une variation en % (ex. "Échec de connexion : 25 (+150 %)"). */
        List<CountByType> previousByType) {

    public record CountByType(AnalyticsEventType type, long count) {
    }
}
