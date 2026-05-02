package com.mobili.backend.module.notification.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class PostChannelMessageRequestDTO {

    @NotBlank
    @Size(max = 2000)
    private String body;
}
