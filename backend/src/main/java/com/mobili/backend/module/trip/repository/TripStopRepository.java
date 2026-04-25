package com.mobili.backend.module.trip.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.mobili.backend.module.trip.entity.TripStop;

public interface TripStopRepository extends JpaRepository<TripStop, Long> {

    List<TripStop> findByTripIdOrderByStopIndexAsc(Long tripId);
}
