package com.mobili.backend.module.booking.booking.entity;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.CascadeType;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "bookings")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Booking extends AbstractEntity {

    @Column(nullable = false, unique = true)
    private String reference;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "user_id", nullable = false)
    private User customer;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "trip_id", nullable = false)
    private Trip trip;

    @Column(nullable = false)
    private Integer numberOfSeats;

    @Column(nullable = false)
    private Double totalPrice;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BookingStatus status;

    private LocalDateTime bookingDate;

    @OneToMany(mappedBy = "booking", cascade = CascadeType.ALL)
    private List<Ticket> tickets = new ArrayList<>();

    @ElementCollection
    @CollectionTable(name = "booking_passenger_names", joinColumns = @JoinColumn(name = "booking_id"))
    @Column(name = "passenger_name")
    private Set<String> passengerNames = new HashSet<>(); // ✅ Changé en Set

    @ElementCollection
    @CollectionTable(name = "booking_seat_numbers", joinColumns = @JoinColumn(name = "booking_id"))
    @Column(name = "seat_number")
    private Set<String> seatNumbers = new HashSet<>();

    private LocalDateTime paidAt;

    /** ID transaction FedaPay (statut relu si le webhook n'atteint pas le serveur, ex. localhost). */
    @Column(name = "fedapay_transaction_id", length = 64)
    private String fedapayTransactionId;

    /** Indice d’arrêt d’embarquement sur la chaîne du voyage (0 = premier arrêt). */
    @Column(name = "boarding_stop_index")
    private Integer boardingStopIndex;

    /** Indice d’arrêt de descente (inclus dans la chaîne ; tronçon occupé = [boarding, alighting)). */
    @Column(name = "alighting_stop_index")
    private Integer alightingStopIndex;

    /**
     * Bagages soute supplémentaires (hors quota inclus) pour cette réservation.
     * Plafond : {@code numberOfSeats * trip.maxExtraHoldBagsPerPassenger}.
     */
    @Column(name = "extra_hold_bags", nullable = false)
    private Integer extraHoldBags = 0;

    @PrePersist
    public void initBooking() {
        this.bookingDate = LocalDateTime.now();
        if (this.status == null) {
            this.status = BookingStatus.PENDING;
        }
        this.reference = "RESERVATION-" + System.currentTimeMillis() % 1000000;
    }
}