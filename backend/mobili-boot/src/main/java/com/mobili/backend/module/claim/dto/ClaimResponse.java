package com.mobili.backend.module.claim.dto;

import com.mobili.backend.module.claim.enums.ClaimReason;
import com.mobili.backend.module.claim.enums.ClaimStatus;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * Vue ADMIN — inclut adminNote (note interne). Pour la vue passager, voir
 * {@link PassengerClaimResponse}, qui n'expose jamais adminNote.
 */
public record ClaimResponse(
        Long id,
        ClaimReason reason,
        ClaimStatus status,
        BookingSummaryResponse booking,
        String message,
        Map<String, String> details,
        String adminNote,
        String resolutionMessage,
        LocalDateTime createdAt,
        LocalDateTime resolvedAt,
        String attachmentPath,
        String attachmentOriginalName,
        String attachmentContentType) {
}
