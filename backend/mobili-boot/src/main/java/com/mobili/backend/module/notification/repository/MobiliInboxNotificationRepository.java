package com.mobili.backend.module.notification.repository;

import com.mobili.backend.module.notification.entity.MobiliInboxNotification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;

public interface MobiliInboxNotificationRepository extends JpaRepository<MobiliInboxNotification, Long> {

    @EntityGraph(attributePaths = { "trip", "sourceChannelMessage" })
    Page<MobiliInboxNotification> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);

    long countByUserIdAndReadAtIsNull(Long userId);

    void deleteAllByUserId(Long userId);

   @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE MobiliInboxNotification n SET n.readAt = :now WHERE n.user.id = :userId AND n.readAt IS NULL")
    int markAllReadForUser(@Param("userId") Long userId, @Param("now") LocalDateTime now);

    @EntityGraph(attributePaths = { "trip", "sourceChannelMessage" })
    Page<MobiliInboxNotification> findByStationIdOrderByCreatedAtDesc(Long stationId, Pageable pageable);

    long countByStationIdAndReadAtIsNull(Long stationId);

    void deleteAllByStationId(Long stationId);

   @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE MobiliInboxNotification n SET n.readAt = :now WHERE n.station.id = :stationId AND n.readAt IS NULL")
    int markAllReadForStation(@Param("stationId") Long stationId, @Param("now") LocalDateTime now);

    long countByUserIdAndSeenAtIsNull(Long userId);

    long countByStationIdAndSeenAtIsNull(Long stationId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE MobiliInboxNotification n SET n.seenAt = :now WHERE n.user.id = :userId AND n.seenAt IS NULL")
    int markAllSeenForUser(@Param("userId") Long userId, @Param("now") LocalDateTime now);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE MobiliInboxNotification n SET n.seenAt = :now WHERE n.station.id = :stationId AND n.seenAt IS NULL")
    int markAllSeenForStation(@Param("stationId") Long stationId, @Param("now") LocalDateTime now);

    void deleteAllByPartnerGareComThreadId(Long threadId);

}