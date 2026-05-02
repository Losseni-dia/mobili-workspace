package com.mobili.backend.module.trip.entity;

import java.time.LocalDateTime;

import com.mobili.backend.shared.abstractEntity.AbstractEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "trip_stop_events")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TripStopEvent extends AbstractEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id", nullable = false)
    private Trip trip;

    @Column(name = "stop_index", nullable = false)
    private int stopIndex;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private TripStopEventType eventType;

    @Column(name = "recorded_at", nullable = false)
    private LocalDateTime recordedAt;
}
