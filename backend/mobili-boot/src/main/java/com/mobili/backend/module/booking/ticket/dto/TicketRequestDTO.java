package com.mobili.backend.module.booking.ticket.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class TicketRequestDTO {
    @NotNull(message = "Le voyage est obligatoire")
    private Long tripId;

    @NotNull(message = "L'utilisateur est obligatoire")
    private Long userId;
}