package com.mobili.backend.module.partnergarecom.dto;

import java.time.LocalDateTime;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class PartnerGareComMessageResponseDTO {
    Long id;
    String body;
    LocalDateTime createdAt;
    Long authorId;
    String authorFirstname;
    String authorLastname;
    String authorLogin;
}
