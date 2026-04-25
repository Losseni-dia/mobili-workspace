package com.mobili.backend.module.booking.ticket.dto;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class TicketResponseDTO {
    private Long tripId;
    private String ticketNumber;
    private String passengerFullName; // firstName + lastName
    private String qrCodeData;
    private String departureCity;
    private String arrivalCity;
    private LocalDateTime departureDateTime;
    private String vehiculePlateNumber;
    private Double price;
    private String status;
    private String partnerName;
    private String seatNumber;
}
