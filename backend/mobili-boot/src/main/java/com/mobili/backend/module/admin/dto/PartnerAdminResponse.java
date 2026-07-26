package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;

public record PartnerAdminResponse(
                Long id,
                String name,
                String email,
                String phone,
                String businessNumber,
                boolean enabled,
                String ownerName,
                String logoUrl,
                String kycFrontUrl,
                String kycBackUrl,
                String rejectionReason,
                boolean covoiturageSoloPool,
                String approvalStatus,
                LocalDateTime createdAt) {
}
