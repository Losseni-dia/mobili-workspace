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

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE MobiliInboxNotification n SET n.readAt = :now WHERE n.user.id = :userId AND n.readAt IS NULL")
    int markAllReadForUser(@Param("userId") Long userId, @Param("now") LocalDateTime now);
}
