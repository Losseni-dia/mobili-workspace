package com.mobili.backend.module.booking.booking.entity;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.entity.TicketStatus;
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

    /**
     * Nombre de bagages soute supplémentaires déjà déclarés/remboursés lors d'annulations
     * précédentes sur cette réservation — jamais automatique, jamais déduit du forfait ou du
     * transport : voir BookingService.cancelTickets/cancelBooking, où l'admin déclare
     * explicitement combien de bagages annuler à chaque fois. Plafonné à {@link #extraHoldBags}
     * cumulé sur toutes les annulations.
     */
    @Column(name = "refunded_extra_hold_bags", nullable = false)
    private Integer refundedExtraHoldBags = 0;

    /**
     * Covoiturage uniquement : date limite pour que le chauffeur réponde
     * (accepte/refuse) à la demande — 24h après la création. Null pour les
     * réservations sur trajets publics (achat direct, pas de validation).
     */
    @Column(name = "driver_response_deadline")
    private LocalDateTime driverResponseDeadline;

    /**
     * Covoiturage uniquement : date limite pour que le passager paie une fois
     * le chauffeur ayant accepté — 30 minutes après l'acceptation. Null tant
     * que le chauffeur n'a pas répondu, ou pour les trajets publics.
     */
    @Column(name = "payment_deadline")
    private LocalDateTime paymentDeadline;

    /**
     * Somme des prix de tickets ayant servi de base au calcul du forfait client
     * (voir BookingFeeService) — hors bagages, avant application du forfait lui-même.
     * Conservé pour traçabilité même si le barème change plus tard (pas de recalcul
     * rétroactif à l'affichage) et pour une analyse tarifaire future sur les seuils.
     */
    @Column(name = "tickets_total_amount")
    private Double ticketsTotalAmount;

    /** Forfait client figé au moment du calcul (100/200/300 FCFA) — voir BookingFeeService. */
    @Column(name = "service_fee")
    private Integer serviceFee;

    /**
     * Vente brute de la compagnie — JAMAIS totalPrice (qui inclut le forfait client, jamais
     * reversé à la compagnie). Seule implémentation de ce calcul dans tout le backend : tout
     * code affichant un montant côté partenaire doit passer par cette méthode, jamais
     * recalculer la formule lui-même (c'est exactement ce qui a fini par diverger — quatre
     * endroits différents utilisaient totalPrice par erreur avant cette centralisation).
     *
     * Dès que des tickets existent avec la scission transportFare/baggageFee (post-chantier
     * commission), le calcul se base sur les tickets ENCORE ACTIFS uniquement (statut
     * différent de ANNULÉ) — sinon un ticket annulé individuellement continuait de peser
     * dans la vente affichée partout (dashboard, Transactions...), sans jamais être
     * recalculé : exactement le décalage remonté en production. Pas de recalcul rétroactif
     * en revanche pour les réservations sans tickets ou antérieures à cette scission : on
     * retombe sur le total figé à la création (ticketsTotalAmount/totalPrice), comme avant.
     */
    @jakarta.persistence.Transient
    public double getGrossAmount() {
        return getActiveTicketsAmount() + getActiveLuggageFee();
    }

    /** Part transport de {@link #getGrossAmount()} — voir son Javadoc pour la logique complète. */
    @jakarta.persistence.Transient
    public double getActiveTicketsAmount() {
        if (hasActiveTicketFareSplit()) {
            if (hasCorruptedTicketFareSplit()) {
                // Sécurité : sur certaines réservations créées sous une ancienne version du
                // calcul (avant correction de la division par numberOfSeats), transportFare a
                // été enregistré à la valeur TOTALE sur chaque ticket au lieu de la part par
                // siège — la somme de tous les tickets (actifs + annulés) dépasse alors très
                // largement ticketsTotalAmount. Dans ce cas précis, on ignore les valeurs
                // stockées (corrompues) et on reproratise ticketsTotalAmount à parts égales sur
                // les seuls tickets encore actifs, plutôt que d'afficher un montant qui AUGMENTE
                // après l'annulation d'un ticket (constaté en production sur RESERVATION-909928).
                return reproratedActiveAmount(ticketsTotalAmount);
            }
            return tickets.stream()
                    .filter(t -> t.getStatus() != TicketStatus.ANNULÉ)
                    .mapToDouble(t -> t.getTransportFare() != null ? t.getTransportFare() : 0.0)
                    .sum();
        }
        // Réservation antérieure au forfait client : totalPrice EST déjà la vente brute
        // (le forfait n'existait pas encore), pas de recalcul rétroactif.
        return ticketsTotalAmount == null ? totalPrice : ticketsTotalAmount;
    }

    /** Part bagage de {@link #getGrossAmount()} — voir son Javadoc pour la logique complète. */
    @jakarta.persistence.Transient
    public double getActiveLuggageFee() {
        if (hasActiveTicketFareSplit()) {
            if (hasCorruptedTicketFareSplit()) {
                double luggageFee = totalPrice - (ticketsTotalAmount != null ? ticketsTotalAmount : 0.0)
                        - (serviceFee != null ? serviceFee : 0);
                return reproratedActiveAmount(Math.max(0.0, luggageFee));
            }
            return tickets.stream()
                    .filter(t -> t.getStatus() != TicketStatus.ANNULÉ)
                    .mapToDouble(t -> t.getBaggageFee() != null ? t.getBaggageFee() : 0.0)
                    .sum();
        }
        if (ticketsTotalAmount == null) {
            return 0.0;
        }
        return extraHoldBags != null && extraHoldBags > 0
                && trip != null && trip.getExtraHoldBagPrice() != null
                        ? extraHoldBags * trip.getExtraHoldBagPrice()
                        : 0.0;
    }

    private boolean hasActiveTicketFareSplit() {
        return tickets != null && !tickets.isEmpty()
                && tickets.stream().anyMatch(t -> t.getTransportFare() != null);
    }

    /**
     * Détecte un historique de transportFare corrompu (voir {@link #getActiveTicketsAmount()}) :
     * la somme de TOUS les tickets (actifs + annulés, pour ne pas être faussé par une annulation
     * déjà en cours) doit rester proche de ticketsTotalAmount — une tolérance de 1 FCFA absorbe
     * les arrondis de division. Rien à détecter si ticketsTotalAmount est absent (pas de
     * référence fiable pour comparer).
     */
    private boolean hasCorruptedTicketFareSplit() {
        if (ticketsTotalAmount == null || numberOfSeats == null || numberOfSeats <= 0) {
            return false;
        }
        double sumAllTickets = tickets.stream()
                .mapToDouble(t -> t.getTransportFare() != null ? t.getTransportFare() : 0.0)
                .sum();
        return sumAllTickets > ticketsTotalAmount + 1.0;
    }

    /** Reproratise `total` à parts égales entre les tickets encore actifs (jamais négatif). */
    private double reproratedActiveAmount(double total) {
        long activeCount = tickets.stream().filter(t -> t.getStatus() != TicketStatus.ANNULÉ).count();
        if (activeCount <= 0) {
            return 0.0;
        }
        return (total / numberOfSeats) * activeCount;
    }

    @PrePersist
    public void initBooking() {
        this.bookingDate = LocalDateTime.now();
        if (this.status == null) {
            this.status = BookingStatus.PENDING;
        }
        this.reference = "RESERVATION-" + System.currentTimeMillis() % 1000000;
    }
}