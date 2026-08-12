package com.mobili.backend.module.booking.ticket.dto;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class TicketResponseDTO {
    /** Utilisé pour cibler l'annulation partielle d'une réservation multi-sièges (Claim.detailsJson). */
    private Long id;
    /** Idem : permet de regrouper les tickets d'une même réservation côté app. */
    private Long bookingId;
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
    private String boardingPoint;
    private String boardingCity;
    private String alightingCity;
    private Integer boardingStopIndex;
    private Integer alightingStopIndex;
    private LocalDateTime bookingDate;
    private Integer extraHoldBags;
    private Double luggageFee;
    private Double transportPrice;
    private Integer numberOfSeatsInBooking;
}