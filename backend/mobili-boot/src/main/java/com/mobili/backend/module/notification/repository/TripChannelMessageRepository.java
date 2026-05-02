package com.mobili.backend.module.notification.repository;

import com.mobili.backend.module.notification.entity.TripChannelMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TripChannelMessageRepository extends JpaRepository<TripChannelMessage, Long> {

    @Query("SELECT m FROM TripChannelMessage m JOIN FETCH m.author WHERE m.trip.id = :tripId ORDER BY m.createdAt ASC")
    List<TripChannelMessage> findByTripIdOrderByCreatedAtAsc(@Param("tripId") Long tripId);
}
