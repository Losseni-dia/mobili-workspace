package com.mobili.backend.module.admincom.dto;

import java.time.LocalDateTime;

public record AdminComMessageDTO(
        Long id,
        Long authorId,
        String authorName,
        String body,
        LocalDateTime createdAt,
        String createdAtFormatted) {
}