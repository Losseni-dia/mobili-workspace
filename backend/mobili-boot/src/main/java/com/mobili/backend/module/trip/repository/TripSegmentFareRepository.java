package com.mobili.backend.module.trip.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.mobili.backend.module.trip.entity.TripSegmentFare;

public interface TripSegmentFareRepository extends JpaRepository<TripSegmentFare, Long> {

    List<TripSegmentFare> findByTrip_IdOrderByFromStopIndexAscToStopIndexAsc(Long tripId);

    Optional<TripSegmentFare> findByTrip_IdAndFromStopIndexAndToStopIndex(
            Long tripId, int fromStopIndex, int toStopIndex);

    void deleteByTrip_Id(Long tripId);
}
