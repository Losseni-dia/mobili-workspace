package com.mobili.backend.module.claim.dto;

import com.mobili.backend.module.claim.enums.ClaimReason;
import com.mobili.backend.module.claim.enums.ClaimStatus;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * Vue PASSAGER — n'expose jamais adminNote (note interne, réservée à l'admin).
 * resolutionMessage est en revanche visible : c'est le message de clôture destiné au
 * passager (voir ClaimService.updateStatus).
 */
public record PassengerClaimResponse(
        Long id,
        ClaimReason reason,
        ClaimStatus status,
        BookingSummaryResponse booking,
        String message,
        Map<String, String> details,
        String resolutionMessage,
        LocalDateTime createdAt,
        LocalDateTime resolvedAt,
        String attachmentPath,
        String attachmentOriginalName,
        String attachmentContentType) {
}
