package com.mobili.backend.module.trip.entity;

import com.mobili.backend.shared.abstractEntity.AbstractEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "trip_segment_fares")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TripSegmentFare extends AbstractEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id", nullable = false)
    private Trip trip;

    @Column(name = "from_stop_index", nullable = false)
    private int fromStopIndex;

    @Column(name = "to_stop_index", nullable = false)
    private int toStopIndex;

    @Column(nullable = false)
    private double price;
}
