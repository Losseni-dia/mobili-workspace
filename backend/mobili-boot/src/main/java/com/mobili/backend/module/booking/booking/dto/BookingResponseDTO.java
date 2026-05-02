package com.mobili.backend.module.booking.booking.dto;


import lombok.Data;
import java.time.LocalDateTime;
import java.util.Set;

import com.mobili.backend.module.booking.booking.entity.BookingStatus;

@Data
public class BookingResponseDTO {
    private Long id;
    private String reference;
    private String customerName;
    private String tripRoute;
    private String departureCity;
    private String arrivalCity;
    /** Villes d'escale (CSV), utile pour recalculer le tronçon côté UI. */
    private String moreInfo;
    private LocalDateTime departureDateTime;
    private LocalDateTime date;
    private Integer numberOfSeats;
    private Set<String> seatNumbers;
    private Set<String> passengerNames;
    /** Montant total de la réservation. */
    private Double totalPrice;
    /** Alias de {@link #totalPrice} conservé pour compatibilité avec les écrans partenaire. */
    private Double amount;
    /** Prix pour une seule place (= totalPrice / numberOfSeats). */
    private Double pricePerSeat;
    /** Index de l'arrêt d'embarquement (0 = ville de départ). */
    private Integer boardingStopIndex;
    /** Index de l'arrêt de descente (dernier = ville d'arrivée). */
    private Integer alightingStopIndex;
    /** Nom de la ville où le voyageur monte. */
    private String boardingCity;
    /** Nom de la ville où le voyageur descend. */
    private String alightingCity;
    private BookingStatus status;
    private LocalDateTime bookingDate;

    /** Bagages soute supplémentaires réservés (hors quota inclus). */
    private Integer extraHoldBags;
    /** Montant des suppléments bagages (estimé : extra × tarif voyage au moment de l’affichage). */
    private Double luggageFee;
}