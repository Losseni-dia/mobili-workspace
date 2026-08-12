package com.mobili.backend.module.booking.booking.dto;


import lombok.Data;
import java.time.LocalDateTime;
import java.util.Set;

import com.mobili.backend.module.booking.booking.entity.BookingStatus;

@Data
public class BookingResponseDTO {
    private Long id;
    private Long tripId;
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
    /** Montant total de la réservation (tickets + forfait client + bagages). */
    private Double totalPrice;
    /**
     * Vente brute de la compagnie (Booking.getGrossAmount()) — JAMAIS totalPrice, qui
     * inclut le forfait client, jamais reversé à la compagnie.
     */
    private Double amount;
    /** Prix pour une seule place (= totalPrice / numberOfSeats). */
    private Double pricePerSeat;
    /**
     * Somme des prix de tickets SEULE (hors forfait client, hors bagages) — c'est ce montant
     * que "Mes réservations" doit afficher, pas totalPrice. Nullable : absent sur les
     * réservations créées avant l'introduction du forfait client, l'app retombe alors sur
     * totalPrice (comportement historique, pas de recalcul rétroactif).
     */
    private Double ticketsTotalAmount;
    /** Forfait client appliqué (100/200/300 FCFA) — null sur les réservations antérieures. */
    private Integer serviceFee;
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
    /**
     * Montant des suppléments bagages (estimé : extra × tarif voyage au moment de
     * l’affichage).
     */
    private Double luggageFee;

    // ── Covoiturage : validation chauffeur ──────────────────────────────
    /**
     * Covoiturage : date limite pour la réponse du chauffeur (24h après création).
     */
    private LocalDateTime driverResponseDeadline;
    /**
     * Covoiturage : date limite de paiement une fois le chauffeur ayant accepté.
     */
    private LocalDateTime paymentDeadline;
    /**
     * Prénom du client — utile côté chauffeur pour évaluer une demande, sans
     * exposer email/téléphone.
     */
    private String customerFirstname;
    private String customerLastname;
    /**
     * Photo de profil publique du client (dossier users/, pas de donnée sensible).
     */
    private String customerAvatarUrl;
}