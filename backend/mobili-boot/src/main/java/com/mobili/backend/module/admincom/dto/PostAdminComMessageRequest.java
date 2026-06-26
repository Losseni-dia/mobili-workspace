package com.mobili.backend.module.admincom.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class PostAdminComMessageRequest {
    @NotBlank
    @Size(max = 4000)
    private String body;
}