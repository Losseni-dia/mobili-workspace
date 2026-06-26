package com.mobili.backend.module.trip.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.mobili.backend.module.trip.entity.TripStopEvent;
import com.mobili.backend.module.trip.entity.TripStopEventType;

public interface TripStopEventRepository extends JpaRepository<TripStopEvent, Long> {

    boolean existsByTripIdAndStopIndexAndEventType(Long tripId, int stopIndex, TripStopEventType type);

    List<TripStopEvent> findByTripIdOrderByStopIndexAscRecordedAtAsc(Long tripId);

    @Query("SELECT MAX(e.stopIndex) FROM TripStopEvent e WHERE e.trip.id = :tripId AND e.eventType = :type")
    Optional<Integer> findMaxStopIndexByTripIdAndEventType(
            @Param("tripId") Long tripId, @Param("type") TripStopEventType type);

    @Modifying
    @Query("DELETE FROM TripStopEvent e WHERE e.trip.id = :tripId AND e.stopIndex = :stopIndex AND e.eventType = :type")
    void deleteByTripIdAndStopIndexAndEventType(
            @Param("tripId") Long tripId, @Param("stopIndex") int stopIndex, @Param("type") TripStopEventType type);
}
