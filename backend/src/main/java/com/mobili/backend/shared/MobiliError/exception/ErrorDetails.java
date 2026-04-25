package com.mobili.backend.shared.MobiliError.exception;

import java.time.LocalDateTime;

public record ErrorDetails(
        LocalDateTime timestamp,
        int status,
        String errorCode,
        String message,
        String path) {
}