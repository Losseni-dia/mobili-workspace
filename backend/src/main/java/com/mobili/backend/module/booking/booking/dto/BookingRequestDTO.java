package com.mobili.backend.module.booking.booking.dto;

import java.util.List;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class BookingRequestDTO {
    @NotNull(message = "L'ID du voyage est obligatoire")
    private Long tripId;

    @NotNull(message = "L'ID de l'utilisateur est obligatoire")
    private Long userId;

    @NotEmpty(message = "La sélection des sièges est obligatoire")
    private List<SeatSelectionDTO> selections; // Contient nom + siège

    @NotNull(message = "Le nombre de places est obligatoire")
    @Min(value = 1)
    private Integer numberOfSeats;

    /** Optionnel : 0 = premier arrêt du voyage (défaut). */
    private Integer boardingStopIndex;

    /** Optionnel : terminus (défaut). */
    private Integer alightingStopIndex;

    /**
     * Bagages soute en <strong>plus</strong> du quota inclus (style FlixBus). Défaut 0.
     * Plafond côté serveur : {@code numberOfSeats * trip.maxExtraHoldBagsPerPassenger}.
     */
    @Min(0)
    private Integer extraHoldBags;

    @Data
    public static class SeatSelectionDTO {
        private String passengerName;
        private String seatNumber;
    }
}