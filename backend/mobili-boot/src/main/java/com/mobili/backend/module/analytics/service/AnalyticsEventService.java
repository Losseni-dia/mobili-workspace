package com.mobili.backend.module.analytics.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.entity.AppAnalyticsEvent;
import com.mobili.backend.module.analytics.repository.AppAnalyticsEventRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class AnalyticsEventService {

    private static final Logger log = LoggerFactory.getLogger(AnalyticsEventService.class);

    private final AppAnalyticsEventRepository repository;

    /**
     * Enregistre un événement dans une transaction séparée : ne bloque jamais le flux principal.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(AnalyticsEventType type, Long userId, String payload) {
        try {
            AppAnalyticsEvent e = new AppAnalyticsEvent();
            e.setEventType(type);
            e.setUserId(userId);
            if (payload != null && payload.length() > 2000) {
                payload = payload.substring(0, 2000);
            }
            e.setPayload(payload);
            repository.save(e);
            log.debug("[Analytics] {} userId={} payload={}", type, userId, payload);
        } catch (Exception ex) {
            log.warn("[Analytics] Échec d'enregistrement pour {} : {}", type, ex.getMessage());
        }
    }
}
