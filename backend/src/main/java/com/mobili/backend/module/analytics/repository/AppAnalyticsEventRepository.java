package com.mobili.backend.module.analytics.repository;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.mobili.backend.module.analytics.entity.AppAnalyticsEvent;

public interface AppAnalyticsEventRepository extends JpaRepository<AppAnalyticsEvent, Long> {

    @Query("SELECT e.eventType, COUNT(e) FROM AppAnalyticsEvent e " +
            "WHERE e.createdAt >= :from GROUP BY e.eventType")
    List<Object[]> countByTypeSince(@Param("from") LocalDateTime from);

    List<AppAnalyticsEvent> findAllByOrderByCreatedAtDesc(Pageable pageable);
}
