package com.mobili.backend.module.analytics.entity;

import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "app_analytics_events")
@Getter
@Setter
@NoArgsConstructor
public class AppAnalyticsEvent extends AbstractEntity {

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private AnalyticsEventType eventType;

    @Column
    private Long userId;

    @Column(length = 2000)
    private String payload;
}
