package com.mobili.backend.module.analytics.repository;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.entity.AppAnalyticsEvent;

public interface AppAnalyticsEventRepository extends JpaRepository<AppAnalyticsEvent, Long> {

    @Query("SELECT e.eventType, COUNT(e) FROM AppAnalyticsEvent e " +
            "WHERE e.createdAt >= :from GROUP BY e.eventType")
    List<Object[]> countByTypeSince(@Param("from") LocalDateTime from);

    /** Même agrégat, borné des deux côtés — pour la période précédente (comparaison en %). */
    @Query("SELECT e.eventType, COUNT(e) FROM AppAnalyticsEvent e " +
            "WHERE e.createdAt >= :from AND e.createdAt < :to GROUP BY e.eventType")
    List<Object[]> countByTypeBetween(@Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

    List<AppAnalyticsEvent> findAllByOrderByCreatedAtDesc(Pageable pageable);

    List<AppAnalyticsEvent> findAllByCreatedAtGreaterThanEqualOrderByCreatedAtDesc(
            LocalDateTime from, Pageable pageable);

    /** Toutes les erreurs serveur de la période — regroupées par classe d'exception côté service. */
    List<AppAnalyticsEvent> findAllByEventTypeAndCreatedAtGreaterThanEqualOrderByCreatedAtDesc(
            AnalyticsEventType eventType, LocalDateTime from);
}
