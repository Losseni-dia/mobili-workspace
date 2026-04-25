package com.mobili.backend.module.notification.entity;

import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThread;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.user.entity.User;
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

import java.time.LocalDateTime;

@Entity
@Table(name = "mobili_inbox_notifications")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class MobiliInboxNotification extends AbstractEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private MobiliNotificationType type;

    @Column(nullable = false, length = 300)
    private String title;

    @Column(nullable = false, length = 2000)
    private String body;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id")
    private Trip trip;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "channel_message_id")
    private TripChannelMessage sourceChannelMessage;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "partner_gare_com_thread_id")
    private PartnerGareComThread partnerGareComThread;

    @Column(name = "read_at")
    private LocalDateTime readAt;
}
