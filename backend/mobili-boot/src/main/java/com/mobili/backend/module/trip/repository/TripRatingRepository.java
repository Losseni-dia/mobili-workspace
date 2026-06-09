package com.mobili.backend.module.trip.repository;

import com.mobili.backend.module.trip.entity.TripRating;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface TripRatingRepository extends JpaRepository<TripRating, Long> {
    Optional<TripRating> findByTripIdAndUserId(Long tripId, Long userId);

    boolean existsByTripIdAndUserId(Long tripId, Long userId);

    long countByTripId(Long tripId);

    @Query("SELECT AVG(r.note) FROM TripRating r WHERE r.trip.id = :tripId")
    Optional<Double> findAverageByTripId(@Param("tripId") Long tripId);

    @Query("SELECT AVG(r.note) FROM TripRating r WHERE r.trip.partner.id = :partnerId")
    Optional<Double> findAverageByPartnerId(@Param("partnerId") Long partnerId);

    @Query("SELECT AVG(r.note) FROM TripRating r WHERE r.trip.station.id = :stationId")
    Optional<Double> findAverageByStationId(@Param("stationId") Long stationId);

}
