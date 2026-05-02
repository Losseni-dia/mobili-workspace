package com.mobili.backend.module.notification.dto;

import lombok.Builder;
import lombok.Value;

import java.time.LocalDateTime;

@Value
@Builder
public class TripChannelMessageResponseDTO {
    Long id;
    String body;
    LocalDateTime createdAt;
    String authorName;
    String authorRole;
}
