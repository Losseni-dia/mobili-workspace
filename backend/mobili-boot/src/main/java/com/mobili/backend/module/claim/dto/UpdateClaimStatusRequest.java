package com.mobili.backend.module.claim.dto;

import com.mobili.backend.module.claim.enums.ClaimStatus;

public record UpdateClaimStatusRequest(ClaimStatus status, String adminNote) {
}
