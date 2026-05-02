package com.mobili.backend.module.admin.dto;

import com.mobili.backend.module.analytics.entity.AnalyticsEventType;

/**
 * Journal d’événements pour l’admin : pas d’e-mail, pas de nom ; identifiants techniques uniquement.
 */
public record AnalyticsRecentEventResponse(
        long id,
        String occurredAt,
        AnalyticsEventType eventType,
        String detail) {
}
