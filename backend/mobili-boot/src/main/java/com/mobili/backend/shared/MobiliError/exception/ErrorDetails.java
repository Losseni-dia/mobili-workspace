package com.mobili.backend.shared.mobiliError.exception;

import java.time.LocalDateTime;
import java.util.Map;

public record ErrorDetails(
        LocalDateTime timestamp,
        int status,
        String errorCode,
        String message,
        String path,
        Map<String, String> errors) {
}