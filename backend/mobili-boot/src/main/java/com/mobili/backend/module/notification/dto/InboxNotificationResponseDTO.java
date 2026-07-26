package com.mobili.backend.module.notification.dto;

import com.mobili.backend.module.notification.entity.MobiliNotificationType;
import lombok.Builder;
import lombok.Value;

import java.time.LocalDateTime;

@Value
@Builder
public class InboxNotificationResponseDTO {
    Long id;
    MobiliNotificationType type;
    String title;
    String body;
    boolean read;
    LocalDateTime createdAt;
    Long tripId;
    String tripRoute;
    Long bookingId;
    Long channelMessageId;
    /** Lien vers /compagnie/messages?thread=… */
    Long partnerGareComThreadId;

    /**
     * Société concernée (nouvelle inscription/resoumission) : permet à l'admin
     * d'ouvrir la fiche.
     */
    Long partnerId;
}
