package com.mobili.backend.module.booking.ticket.entity;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "tickets")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Ticket extends AbstractEntity {

    @Column(nullable = false, unique = true)
    private String ticketNumber;

    // Le compte User qui possède/gère le ticket (Toi)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User passenger;

    // LE NOM ÉCRIT SUR LE TICKET (Toi ou ton ami)
    @Column(nullable = false)
    private String passengerName;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id", nullable = false)
    private Trip trip;

    @Column(nullable = false)
    private LocalDateTime bookingDate;

    @Column(nullable = false)
    private Double amountPaid;

    @Enumerated(EnumType.STRING)
    private TicketStatus status;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id", nullable = false)
    private Booking booking;

    @Column(nullable = false)
    private String seatNumber; // Ex: "A1", "12"

    @Column(nullable = false)
    private boolean scanned = false; // Pour la validation à la montée

    private LocalDateTime scannedAt;

    @Column(name = "boarding_stop_index")
    private Integer boardingStopIndex;

    @Column(name = "alighting_stop_index")
    private Integer alightingStopIndex;

    /** Renseigné quand le chauffeur confirme la descente à cet arrêt ; libère le siège sur les tronçons suivants. */
    @Column(name = "alighted_at_stop_index")
    private Integer alightedAtStopIndex;

    private LocalDateTime alightedAt;

    /**
     * Part transport (post-coupon) de CE ticket — distincte de baggageFee (jamais fusionnées,
     * nécessaire pour calculer/auditer la commission compagnie sans ambiguïté). Différent de
     * amountPaid, qui mélange transport + forfait client + bagages pour l'affichage passager.
     */
    @Column(name = "transport_fare")
    private Double transportFare;

    /** Part bagage (répartition égale du luggageFee de la réservation) de CE ticket. */
    @Column(name = "baggage_fee")
    private Double baggageFee;

    /** Taux de commission figé appliqué à ce ticket (0.09/0.07/0.05) — voir CompanyCommissionService. */
    @Column(name = "commission_rate")
    private Double commissionRate;

    /** Commission figée (FCFA, arrondie au supérieur) appliquée à ce ticket. */
    @Column(name = "commission_amount")
    private Integer commissionAmount;

    /**
     * Position de ce ticket dans le compteur mensuel de la compagnie au moment de la vente
     * (ex. 499) — explique a posteriori pourquoi ce taux a été choisi, sans recalcul.
     */
    @Column(name = "monthly_sequence_number")
    private Integer monthlySequenceNumber;

    @PrePersist
    public void generateTicketNumber() {
        if (this.ticketNumber == null) {
            this.ticketNumber = "MOB-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
            this.bookingDate = LocalDateTime.now();
            this.status = TicketStatus.VALIDÉ;
        }
    }
}