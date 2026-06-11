package com.mobili.backend.module.partner.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RecentBookingDTO {
    private Long id;
    private String customerName; // Sera mappé via MapStruct
    private String tripRoute; // Sera mappé via MapStruct (Départ -> Arrivée)
    private LocalDateTime date; // Mappé depuis createdAt
    private double amount; // Mappé depuis totalPrice
    private String status; // Mappé depuis l'Enum status
    private List<String> passengerNames; // Noms des passagers
    private List<String> seatNumbers; // Numéros de sièges
}