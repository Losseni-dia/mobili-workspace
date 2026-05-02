package com.mobili.backend.module.trip.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.mobili.backend.module.trip.entity.TripStopEvent;
import com.mobili.backend.module.trip.entity.TripStopEventType;

public interface TripStopEventRepository extends JpaRepository<TripStopEvent, Long> {

    boolean existsByTripIdAndStopIndexAndEventType(Long tripId, int stopIndex, TripStopEventType type);

    List<TripStopEvent> findByTripIdOrderByStopIndexAscRecordedAtAsc(Long tripId);
}
