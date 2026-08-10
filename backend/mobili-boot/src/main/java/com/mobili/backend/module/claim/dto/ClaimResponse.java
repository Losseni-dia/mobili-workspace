package com.mobili.backend.module.claim.dto;

import com.mobili.backend.module.claim.enums.ClaimReason;
import com.mobili.backend.module.claim.enums.ClaimStatus;

import java.time.LocalDateTime;
import java.util.Map;

public record ClaimResponse(
        Long id,
        ClaimReason reason,
        ClaimStatus status,
        BookingSummaryResponse booking,
        String message,
        Map<String, String> details,
        String adminNote,
        LocalDateTime createdAt,
        LocalDateTime resolvedAt) {
}
