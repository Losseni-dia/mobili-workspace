package com.mobili.backend.module.admincom.dto;

import java.time.LocalDateTime;

/**
 * [attachmentPath] : chemin relatif servi via {@code GET /media/private?rel=...} (JWT requis),
 * {@code null} si le message n'a pas de pièce jointe.
 */
public record AdminComMessageDTO(
        Long id,
        Long authorId,
        String authorName,
        String body,
        LocalDateTime createdAt,
        String createdAtFormatted,
        String attachmentPath,
        String attachmentOriginalName,
        String attachmentContentType) {
}