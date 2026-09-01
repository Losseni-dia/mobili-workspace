package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;

/** Classement des exceptions serveur (SERVER_ERROR) par fréquence — page Analyse app. */
public record TopErrorEntryResponse(
        String exceptionClass,
        long count,
        LocalDateTime lastOccurredAt) {
}
