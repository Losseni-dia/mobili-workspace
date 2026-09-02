package com.mobili.backend.module.booking.booking.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.booking.booking.dto.BookingRequestDTO;
import com.mobili.backend.module.booking.booking.dto.ManualBlockRequest;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.entity.TicketStatus;
import com.mobili.backend.module.booking.ticket.service.TicketService;
import com.mobili.backend.module.coupon.service.CouponService;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.payment.entity.Payment;
import com.mobili.backend.module.payment.repository.PaymentRepository;
import com.mobili.backend.module.payment.service.PaymentRefundService;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.pricing.dto.CommissionResult;
import com.mobili.backend.module.pricing.service.BookingFeeService;
import com.mobili.backend.module.pricing.service.CompanyCommissionService;
import com.mobili.backend.module.pricing.service.PartnerMonthlyVolumeService;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.service.TripPricingService;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
@RequiredArgsConstructor
public class BookingService {

    private final BookingRepository bookingRepository;
    private final TripService tripService;
    private final TripRepository tripRepository;
    private final UserService userService;
    private final TicketService ticketService;
    private final UserRepository userRepository;
    private final PartnerService partenaireService;
    private final TripRunService tripRunService;
    private final TripPricingService tripPricingService;
    private final AnalyticsEventService analyticsEventService;
    private final CouponService couponService;
    private final com.mobili.backend.module.payment.service.PaymentRefundService paymentRefundService;
    private final com.mobili.backend.module.payment.repository.PaymentRepository paymentRepository;
    private final InboxNotificationService inboxNotificationService;
    private final BookingFeeService bookingFeeService;
    private final CompanyCommissionService companyCommissionService;
    private final PartnerMonthlyVolumeService partnerMonthlyVolumeService;


    @Transactional(readOnly = true)
    public List<Booking> findConfirmedByTripId(Long tripId) {
        return bookingRepository.findConfirmedByTripIdWithDetails(tripId);
    }

    @Transactional(readOnly = true)
    public List<Booking> findAllPendingCovoiturageRequestsForOrganizer(Long organizerId) {
        List<Booking> bookings = bookingRepository.findPendingCovoiturageRequestsForOrganizer(organizerId);
        bookings.forEach(this::initLazyCollections);
        return bookings;
    }

    @Transactional
    public Booking createOfflineSale(BookingRequestDTO dto) {
        Booking booking = create(dto);

        // Vente guichet (sur place) : aucun forfait de service — ce forfait finance
        // uniquement la commodité du paiement en ligne (Stripe/FedaPay), jamais pertinent pour
        // un passager qui paie physiquement à la gare. create() calcule pourtant le forfait de
        // façon identique au flux en ligne (computePricing, aucune distinction de canal) : on le
        // retire ici du prix total AVANT de figer le statut OFFLINE_SALE et de générer les
        // tickets, pour que amountPaid par ticket (TicketService.createFromBooking, dérivé de
        // booking.getTotalPrice()) ne comprenne jamais ce forfait fantôme (incident constaté en
        // prod le 2026-09-02).
        if (booking.getServiceFee() != null && booking.getServiceFee() > 0) {
            booking.setTotalPrice(booking.getTotalPrice() - booking.getServiceFee());
            booking.setServiceFee(0);
        }

        booking.setStatus(BookingStatus.OFFLINE_SALE);
        booking = bookingRepository.save(booking);

        // BUG CONSTATÉ EN PRODUCTION : aucun Ticket n'était jamais généré pour une vente
        // guichet — seul le Booking était persisté. Une vente OFFLINE_SALE n'apparaissait
        // donc jamais dans les pages "Tickets" (partenaire/admin), qui lisent la table
        // tickets, tout en comptant normalement dans "Mes réservations" (qui lit
        // directement Booking.seatNumbers/passengerNames). Même génération que
        // confirmPayment()/confirmBookingAfterPayment() : un Ticket par siège/passager,
        // avec sa part de tarif et sa commission.
        Trip fresh = tripRepository.findByIdWithPartnerAndStops(booking.getTrip().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        generateTicketsWithCommission(booking, fresh.getPartner());

        return booking;
    }

    /**
     * Rattrapage ponctuel (à exécuter une fois, via l'endpoint admin dédié) : génère les tickets
     * manquants pour toute vente guichet (OFFLINE_SALE) enregistrée avant le correctif de
     * {@link #createOfflineSale}. Idempotent — ne retraite jamais une réservation qui a déjà au
     * moins un ticket (voir BookingRepository.findOfflineSaleBookingsWithoutTickets, filtre
     * `b.tickets IS EMPTY`), donc sans risque de double génération si relancé plusieurs fois.
     *
     * @return nombre de réservations effectivement corrigées.
     */
    @Transactional
    public int backfillMissingOfflineSaleTickets() {
        List<Booking> bookings = bookingRepository.findOfflineSaleBookingsWithoutTickets();
        int fixed = 0;
        for (Booking booking : bookings) {
            Trip trip = booking.getTrip();
            if (trip == null || trip.getPartner() == null) {
                log.warn("⚠️ Rattrapage tickets guichet : Booking #{} sans trajet/partenaire exploitable, ignoré.",
                        booking.getId());
                continue;
            }
            generateTicketsWithCommission(booking, trip.getPartner());
            fixed++;
        }
        log.info("🎫 Rattrapage tickets guichet : {} réservation(s) corrigée(s) sur {} trouvée(s) sans ticket.",
                fixed, bookings.size());
        return fixed;
    }

    /**
     * Rattrapage ponctuel (à exécuter une fois, via l'endpoint admin dédié) : retire le forfait
     * de service client des ventes guichet (OFFLINE_SALE) créées AVANT le correctif de
     * {@link #createOfflineSale} (2026-09-02) — un paiement sur place n'a jamais dû inclure ce
     * forfait, qui finance uniquement la commodité du paiement en ligne. Recalcule aussi
     * amountPaid de chaque ticket déjà généré (dérivé de booking.getTotalPrice(), qui contenait
     * le forfait à la création). Idempotent — ne retraite jamais une réservation dont le
     * serviceFee est déjà à 0 (voir BookingRepository.findOfflineSaleBookingsWithServiceFee,
     * filtre {@code b.serviceFee > 0}), donc sans risque de double retrait si relancé plusieurs
     * fois. Ne touche jamais les réservations en ligne (CONFIRMED), dont le forfait reste dû.
     *
     * @return nombre de réservations effectivement corrigées.
     */
    @Transactional
    public int backfillOfflineSaleServiceFee() {
        List<Booking> bookings = bookingRepository.findOfflineSaleBookingsWithServiceFee();
        int fixed = 0;
        for (Booking booking : bookings) {
            int oldServiceFee = booking.getServiceFee();
            double newTotalPrice = booking.getTotalPrice() - oldServiceFee;
            booking.setTotalPrice(newTotalPrice);
            booking.setServiceFee(0);

            int seats = Math.max(1, booking.getNumberOfSeats());
            double newAmountPaid = newTotalPrice / seats;
            for (Ticket t : booking.getTickets()) {
                t.setAmountPaid(newAmountPaid);
            }

            bookingRepository.save(booking);
            fixed++;
            log.info("💰 Rattrapage forfait guichet : Booking #{} — forfait {} FCFA retiré (nouveau total {} FCFA).",
                    booking.getId(), oldServiceFee, newTotalPrice);
        }
        log.info("💰 Rattrapage forfait guichet : {} réservation(s) corrigée(s) sur {} trouvée(s) avec forfait.",
                fixed, bookings.size());
        return fixed;
    }

    /**
     * @param declaredBagsToCancel nombre de bagages soute supplémentaires à rembourser pour
     *                             CETTE annulation — jamais automatique/déduit de baggageFee,
     *                             toujours déclaré explicitement par l'admin (voir
     *                             {@link #refundDeclaredBaggage}). 0 si aucun bagage à rembourser.
     * @return montant remboursé (FCFA, jamais le forfait) — 0 si aucun ticket actif n'a été
     *         annulé ET aucun bagage déclaré.
     */
    @Transactional
    public double cancelBooking(Long bookingId, int declaredBagsToCancel) {
        Booking booking = bookingRepository.findByIdWithDetails(bookingId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));

        // Vérifier si la réservation peut être annulée
        if (booking.getStatus() == BookingStatus.CANCELLED) {
            log.warn("⚠️ Réservation {} déjà annulée.", bookingId);
            return 0;
        }

        booking.setStatus(BookingStatus.CANCELLED);

        // Cascade vers les tickets : sans ça, un ticket restait VALIDÉ alors que sa
        // réservation passait CANCELLED — décalage constaté côté partenaire/gare/admin (le
        // ticket ne "passait" jamais dans la liste des annulés). On laisse UTILISÉ tel quel :
        // un ticket déjà scanné à l'embarquement ne peut pas être rétroactivement invalidé.
        List<Ticket> justCancelled = new ArrayList<>();
        for (Ticket t : booking.getTickets()) {
            if (t.getStatus() == TicketStatus.VALIDÉ) {
                t.setStatus(TicketStatus.ANNULÉ);
                justCancelled.add(t);
            }
        }

        double baggageRefund = refundDeclaredBaggage(booking, declaredBagsToCancel);
        bookingRepository.save(booking);

        // Libération immédiate du siège : seatsOccupiedOnLeg() (TripRunService) exclut déjà
        // les réservations CANCELLED de l'occupation réelle — un nouveau client peut donc déjà
        // re-réserver ce siège dès l'instant présent. Le seul trou : availableSeats (compteur
        // caché affiché aux clients) n'était pas rafraîchi ici, contrairement à
        // confirmBookingAfterPayment/confirmPayment qui le font déjà — même pattern appliqué ici.
        Trip trip = tripRepository.findByIdWithPartnerAndStops(booking.getTrip().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        tripRunService.ensureStops(trip);
        tripRunService.refreshTripAvailableSeatsCounter(trip);
        tripRepository.save(trip);

        double refundable = computeRefundableAmount(justCancelled) + baggageRefund;
        triggerRefund(bookingId, refundable);

        log.info("✅ Réservation #{} annulée et processus de remboursement initié", bookingId);
        return refundable;
    }

    /**
     * Annulation ciblée d'un sous-ensemble des tickets d'UNE réservation (ex. 1 siège sur 3) —
     * demandée via réclamation passager, exécutée par un admin (voir AdminBookingController).
     * Si tous les tickets encore actifs de la réservation finissent annulés par cet appel, la
     * réservation elle-même bascule CANCELLED (même cascade que cancelBooking, pas de double
     * remboursement puisqu'on ne rembourse ici que les tickets qu'on vient d'annuler).
     */
    /**
     * @param declaredBagsToCancel nombre de bagages soute supplémentaires à rembourser pour
     *                             CETTE annulation — voir {@link #refundDeclaredBaggage}.
     * @return montant remboursé (FCFA, jamais le forfait) — 0 si aucun ticket ciblé n'a été
     *         annulé ET aucun bagage déclaré.
     */
    @Transactional
    public double cancelTickets(Long bookingId, List<Long> ticketIds, int declaredBagsToCancel) {
        if (ticketIds == null || ticketIds.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Aucun ticket sélectionné.");
        }
        Booking booking = bookingRepository.findByIdWithDetails(bookingId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));

        if (booking.getStatus() == BookingStatus.CANCELLED) {
            log.warn("⚠️ Réservation {} déjà annulée.", bookingId);
            return 0;
        }

        Set<Long> targetIds = new HashSet<>(ticketIds);
        List<Ticket> justCancelled = new ArrayList<>();
        for (Ticket t : booking.getTickets()) {
            if (!targetIds.contains(t.getId())) {
                continue;
            }
            if (t.getStatus() == TicketStatus.VALIDÉ) {
                t.setStatus(TicketStatus.ANNULÉ);
                justCancelled.add(t);
            }
        }

        if (justCancelled.isEmpty()) {
            log.warn("⚠️ Aucun ticket VALIDÉ parmi {} pour la réservation {} — rien à annuler.",
                    ticketIds, bookingId);
            return 0;
        }

        // Ne teste pas QUE VALIDÉ : un ticket déjà UTILISÉ (scanné à l'embarquement) ou ARRIVÉ
        // est tout aussi "actif/honoré" qu'un VALIDÉ — seul ANNULÉ ne l'est pas. Avant ce
        // correctif (incident constaté en prod le 2026-09-02), une réservation à 2 tickets dont
        // 1 UTILISÉ + 1 qu'on venait d'annuler basculait quand même en CANCELLED (aucun VALIDÉ
        // restant), alors qu'elle contenait encore un billet bien vendu et honoré — Stats métier
        // (qui filtrait alors sur le statut de la réservation) excluait ce ticket à tort.
        boolean anyStillActive = booking.getTickets().stream()
                .anyMatch(t -> t.getStatus() == TicketStatus.VALIDÉ
                        || t.getStatus() == TicketStatus.UTILISÉ
                        || t.getStatus() == TicketStatus.ARRIVÉ);
        if (!anyStillActive) {
            // Dernier ticket actif annulé : la réservation suit, comme cancelBooking().
            booking.setStatus(BookingStatus.CANCELLED);
        }

        double baggageRefund = refundDeclaredBaggage(booking, declaredBagsToCancel);
        bookingRepository.save(booking);

        Trip trip = tripRepository.findByIdWithPartnerAndStops(booking.getTrip().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        tripRunService.ensureStops(trip);
        tripRunService.refreshTripAvailableSeatsCounter(trip);
        tripRepository.save(trip);

        double refundable = computeRefundableAmount(justCancelled) + baggageRefund;
        triggerRefund(bookingId, refundable);

        log.info("✅ {} ticket(s) annulé(s) sur la réservation #{} ({})",
                justCancelled.size(), bookingId,
                anyStillActive ? "résa toujours active" : "résa entièrement annulée");
        return refundable;
    }

    /**
     * Déclenche le remboursement Stripe (seul provider avec remboursement automatique).
     *
     * AUDIT-MOBILI.md §1.3 : findByBookingIdAndProvider (Optional, résultat unique attendu,
     * sans filtre de statut) pouvait lever IncorrectResultSizeDataAccessException si un
     * paiement Stripe avait échoué puis été retenté avec succès (2 lignes Payment
     * provider=STRIPE pour cette réservation), et risquait sinon de rembourser via
     * l'externalReference d'un paiement FAILED/PENDING plutôt que celui réellement payé.
     * findAllByBookingIdAndProviderAndStatusInOrderByIdDesc filtre sur SUCCESS/REFUNDED et prend
     * le plus récent en cas de doublon — jamais d'exception, jamais le mauvais paiement. REFUNDED
     * est inclus depuis le 2026-09-02 : une réservation à plusieurs tickets annulés en plusieurs
     * fois voit son paiement passer REFUNDED dès le 1er remboursement partiel
     * (PaymentRefundService.refund) — sans ce statut en plus, une 2e annulation ne retrouvait
     * plus aucun paiement à rembourser et l'argent des tickets annulés ensuite n'était jamais
     * reversé au client (le seul symptôme visible côté admin était un message trompeur "aucun
     * paiement lié à cette réservation").
     */
    private void triggerRefund(Long bookingId, double amount) {
        if (amount <= 0) {
            return;
        }
        List<Payment> stripePayments = paymentRepository.findAllByBookingIdAndProviderAndStatusInOrderByIdDesc(
                bookingId,
                com.mobili.backend.module.payment.enums.PaymentProvider.STRIPE,
                java.util.List.of(
                        com.mobili.backend.module.payment.enums.PaymentStatus.SUCCESS,
                        com.mobili.backend.module.payment.enums.PaymentStatus.REFUNDED));
        if (stripePayments.isEmpty()) {
            return;
        }
        Payment payment = stripePayments.get(0);
        log.info("💳 Remboursement de {} FCFA pour Booking #{}", Math.round(amount), bookingId);
        paymentRefundService.refund(payment.getExternalReference(), Math.round(amount));
    }

    /**
     * Montant remboursable pour CES tickets — JAMAIS le forfait client (frais irrécupérables
     * chez l'agrégateur de paiement in/out, jamais reversés à Mobili elle-même, donc jamais
     * remboursables au passager), et JAMAIS le bagage automatiquement (voir
     * {@link #refundDeclaredBaggage} — l'admin doit déclarer explicitement combien de bagages
     * rembourser, jamais déduit de baggageFee ici). Repose sur transportFare, figé par ticket à
     * la vente. Pour un ticket antérieur à cette scission (transportFare null), on retombe sur
     * amountPaid en meilleur effort — inclut alors une part de forfait (et de bagage) qu'on ne
     * peut plus isoler rétroactivement, comme partout ailleurs dans ce fichier pour les données
     * historiques.
     */
    private double computeRefundableAmount(List<Ticket> tickets) {
        double total = 0;
        for (Ticket t : tickets) {
            if (t.getTransportFare() != null) {
                total += t.getTransportFare();
            } else if (t.getAmountPaid() != null) {
                total += t.getAmountPaid();
            }
        }
        return total;
    }

    /**
     * Bagage soute supplémentaire à rembourser pour CETTE annulation — jamais automatique
     * (contrairement à l'ancien calcul via baggageFee) : l'admin déclare explicitement combien
     * de bagages annuler, potentiellement en plusieurs fois sur la même réservation. Plafonné au
     * total réellement enregistré ({@link Booking#getExtraHoldBags()}) cumulé sur toutes les
     * annulations déjà effectuées ({@link Booking#getRefundedExtraHoldBags()}) — empêche de
     * rembourser plus de bagages qu'il n'y en a, même en plusieurs fois.
     *
     * @return montant à ajouter au remboursement (FCFA) — 0 si declaredBagsToCancel est 0.
     */
    private double refundDeclaredBaggage(Booking booking, int declaredBagsToCancel) {
        if (declaredBagsToCancel <= 0) {
            return 0;
        }
        int totalBags = booking.getExtraHoldBags() != null ? booking.getExtraHoldBags() : 0;
        int alreadyRefunded = booking.getRefundedExtraHoldBags() != null ? booking.getRefundedExtraHoldBags() : 0;
        int remaining = totalBags - alreadyRefunded;
        if (declaredBagsToCancel > remaining) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Impossible de rembourser " + declaredBagsToCancel + " bagage(s) : seulement "
                            + remaining + " encore remboursable(s) sur " + totalBags + " enregistré(s) au total.");
        }
        Trip trip = booking.getTrip();
        double unitBagPrice = trip != null && trip.getExtraHoldBagPrice() != null ? trip.getExtraHoldBagPrice() : 0.0;
        booking.setRefundedExtraHoldBags(alreadyRefunded + declaredBagsToCancel);
        return declaredBagsToCancel * unitBagPrice;
    }

    @Transactional
    public Booking create(BookingRequestDTO request) {
        Trip trip = tripService.findById(request.getTripId());
        User user = userService.findById(request.getUserId());
        int requestedSeats = request.getNumberOfSeats();

        // Verrou pessimiste sur la ligne du trajet, tenu jusqu'au commit de cette
        // transaction : sérialise les créations de réservation concurrentes sur ce même
        // trajet, pour que assertSeatsAvailableOnSegment/minFreeSeatsOnSegment ci-dessous
        // voient toujours l'état de sièges réellement à jour (fixe la race condition où deux
        // requêtes simultanées passaient toutes deux la vérification pour le même siège).
        tripRunService.lockTrip(trip);

        tripRunService.ensureStops(trip);
        int lastStop = tripRunService.lastStopIndex(trip);
        int boarding = request.getBoardingStopIndex() != null ? request.getBoardingStopIndex() : 0;
        int alighting = request.getAlightingStopIndex() != null ? request.getAlightingStopIndex() : lastStop;

        tripRunService.validateSegment(trip, boarding, alighting);
        tripRunService.assertBoardingStillOpen(trip, boarding, LocalDateTime.now());

        List<String> seats = request.getSelections().stream()
                .map(BookingRequestDTO.SeatSelectionDTO::getSeatNumber)
                .toList();
        tripRunService.assertSeatsAvailableOnSegment(trip, boarding, alighting, seats);

        int minFree = tripRunService.minFreeSeatsOnSegment(trip, boarding, alighting);
        if (minFree < requestedSeats) {
            throw new MobiliException(MobiliErrorCode.NO_SEATS_AVAILABLE,
                    "Places insuffisantes sur une portion du trajet.");
        }

        int extraBags = request.getExtraHoldBags() != null ? request.getExtraHoldBags() : 0;
        if (extraBags < 0) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Nombre de bagages supplémentaires invalide.");
        }
        int maxExtraPerPax = trip.getMaxExtraHoldBagsPerPassenger() != null
                ? trip.getMaxExtraHoldBagsPerPassenger()
                : 1;
        int maxExtraForBooking = requestedSeats * maxExtraPerPax;
        if (extraBags > maxExtraForBooking) {
            throw new MobiliException(
                    MobiliErrorCode.VALIDATION_ERROR,
                    "Trop de bagages soute en supplément (max. "
                            + maxExtraForBooking
                            + " pour "
                            + requestedSeats
                            + " place(s) sur ce service).");
        }

        // Même séquence de calcul que previewPrice(...) — partagée, jamais dupliquée, pour
        // que le montant prévisualisé par le passager avant paiement soit garanti identique
        // au montant réellement facturé ici.
        PricingBreakdown pricing = computePricing(
                trip, boarding, alighting, requestedSeats, extraBags, request.getCouponCode());

        Booking booking = new Booking();
        booking.setTrip(trip);
        booking.setCustomer(user);
        booking.setNumberOfSeats(requestedSeats);
        booking.setTicketsTotalAmount(pricing.seatSubtotal());
        booking.setServiceFee(pricing.serviceFee());
        // totalPrice (pas perSeatPrice * requestedSeats) : inclut la remise
        // coupon déjà appliquée plus haut — recalculer depuis
        // perSeatPrice * requestedSeats ici l'ignorait silencieusement, le
        // prix final (et donc le montant facturé via Stripe/FedaPay,
        // PaymentController.createCheckout) restait au prix plein malgré un
        // coupon valide.
        booking.setTotalPrice(pricing.total());
        booking.setExtraHoldBags(extraBags);
        booking.setBoardingStopIndex(boarding);
        booking.setAlightingStopIndex(alighting);

        boolean isCovoiturage = trip.getCovoiturageOrganizer() != null;
        if (isCovoiturage) {
            booking.setStatus(BookingStatus.PENDING_DRIVER_APPROVAL);
            booking.setDriverResponseDeadline(LocalDateTime.now().plusHours(24));
        } else {
            booking.setStatus(BookingStatus.PENDING);
        }

        List<String> names = request.getSelections().stream()
                .map(BookingRequestDTO.SeatSelectionDTO::getPassengerName)
                .toList();

        booking.setPassengerNames(new HashSet<>(names));
        booking.setSeatNumbers(new HashSet<>(seats));

        Booking saved = bookingRepository.save(booking);

        Trip fresh = tripRepository.findByIdWithPartnerAndStops(trip.getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        tripRunService.ensureStops(fresh);
        tripRunService.refreshTripAvailableSeatsCounter(fresh);
        tripRepository.save(fresh);

        analyticsEventService.record(
                AnalyticsEventType.BOOKING_CREATED,
                user.getId(),
                String.format("{\"bookingId\":%d,\"tripId\":%d}", saved.getId(), trip.getId()));

        if (isCovoiturage) {
            inboxNotificationService.notifyDriverOnNewCovoiturageRequest(saved);
        }

        return saved;
    }

    /** Décomposition tarifaire d'une réservation — partagée entre create() et previewPrice(). */
    public record PricingBreakdown(
            double perSeatPrice, double seatSubtotal, int serviceFee, double luggageFee, double total) {
    }

    /**
     * Séquence de calcul du prix — extraite de create() pour être réutilisée à l'identique par
     * previewPrice() (aucune divergence possible entre le montant prévisualisé avant paiement
     * et le montant réellement facturé). N'écrit rien en base, ne fait aucune vérification de
     * disponibilité de sièges (ce n'est pas son rôle : la disponibilité est vérifiée séparément
     * dans create(), le preview reste un simple calcul de prix).
     */
    private PricingBreakdown computePricing(Trip trip, int boarding, int alighting, int requestedSeats,
            int extraBags, String couponCode) {
        double perSeatPrice = tripPricingService.resolvePricePerSeat(trip, boarding, alighting);
        double seatSubtotal = perSeatPrice * requestedSeats;

        if (couponCode != null && !couponCode.isEmpty()) {
            seatSubtotal = couponService.applyCoupon(couponCode, BigDecimal.valueOf(seatSubtotal)).doubleValue();
        }

        // Forfait client : calculé UNE SEULE FOIS par réservation, sur la base de la somme
        // des prix de tickets (seatSubtotal ici, post-coupon, AVANT le forfait lui-même et
        // AVANT les bagages) — jamais sur le total bagages inclus.
        int serviceFee = bookingFeeService.calculateBookingFee(seatSubtotal);

        double unitBagPrice = trip.getExtraHoldBagPrice() != null ? trip.getExtraHoldBagPrice() : 0.0;
        double luggageFee = extraBags * unitBagPrice;

        double total = seatSubtotal + serviceFee + luggageFee;
        return new PricingBreakdown(perSeatPrice, seatSubtotal, serviceFee, luggageFee, total);
    }

    /**
     * Prévisualisation du prix — mêmes calculs que create() (via computePricing), sans créer
     * de réservation. Utilisé côté passager pour afficher le détail (sous-total, forfait,
     * bagages, total) avant paiement.
     */
    @Transactional(readOnly = true)
    public PricingBreakdown previewPrice(Long tripId, int requestedSeats, Integer boardingStopIndex,
            Integer alightingStopIndex, Integer extraHoldBags, String couponCode) {
        Trip trip = tripService.findById(tripId);
        tripRunService.ensureStops(trip);
        int lastStop = tripRunService.lastStopIndex(trip);
        int boarding = boardingStopIndex != null ? boardingStopIndex : 0;
        int alighting = alightingStopIndex != null ? alightingStopIndex : lastStop;
        tripRunService.validateSegment(trip, boarding, alighting);

        int extraBags = extraHoldBags != null ? extraHoldBags : 0;
        if (extraBags < 0) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Nombre de bagages supplémentaires invalide.");
        }

        return computePricing(trip, boarding, alighting, requestedSeats, extraBags, couponCode);
    }

    /**
     * Le chauffeur accepte une demande covoiturage : le passager a 30 minutes
     * pour payer, sinon la place est automatiquement libérée (voir
     * {@link com.mobili.backend.module.booking.booking.scheduler.CovoiturageBookingExpiryScheduler}).
     */
    @Transactional
    public void acceptCovoiturageRequest(Long bookingId, UserPrincipal principal) {
        Booking booking = bookingRepository.findByIdWithDetails(bookingId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));
        assertIsCovoiturageOrganizer(booking, principal);
        if (booking.getStatus() != BookingStatus.PENDING_DRIVER_APPROVAL) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Cette demande n'est plus en attente de validation.");
        }
        booking.setStatus(BookingStatus.AWAITING_PAYMENT);
        booking.setPaymentDeadline(LocalDateTime.now().plusMinutes(30));
        bookingRepository.save(booking);
        inboxNotificationService.notifyPassengerOnCovoiturageDecision(booking, true);
    }

    /**
     * Le chauffeur refuse une demande covoiturage : la place doit redevenir
     * immédiatement disponible pour d'autres demandes, pas seulement à la
     * prochaine réservation qui déclencherait un recalcul.
     */
    @Transactional
    public void rejectCovoiturageRequest(Long bookingId, UserPrincipal principal) {
        Booking booking = bookingRepository.findByIdWithDetails(bookingId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));
        assertIsCovoiturageOrganizer(booking, principal);
        if (booking.getStatus() != BookingStatus.PENDING_DRIVER_APPROVAL) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Cette demande n'est plus en attente de validation.");
        }
        booking.setStatus(BookingStatus.REJECTED_BY_DRIVER);
        bookingRepository.save(booking);

        Trip fresh = tripRepository.findByIdWithPartnerAndStops(booking.getTrip().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        tripRunService.ensureStops(fresh);
        tripRunService.refreshTripAvailableSeatsCounter(fresh);
        tripRepository.save(fresh);

        inboxNotificationService.notifyPassengerOnCovoiturageDecision(booking, false);
    }

    /**
     * Demandes covoiturage en attente de décision, pour un trajet donné —
     * consultées par le chauffeur (nom, prénom, photo du passager uniquement).
     */
    @Transactional(readOnly = true)
    public List<Booking> findPendingCovoiturageRequestsForTrip(Long tripId, UserPrincipal principal) {
        Trip trip = tripService.findById(tripId);
        if (trip.getCovoiturageOrganizer() == null
                || !trip.getCovoiturageOrganizer().getId().equals(principal.getUser().getId())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Vous n'êtes pas l'organisateur de ce trajet.");
        }
        List<Booking> bookings = bookingRepository.findByTripIdAndStatus(tripId, BookingStatus.PENDING_DRIVER_APPROVAL);
        bookings.forEach(this::initLazyCollections);
        return bookings;
    }

    private void assertIsCovoiturageOrganizer(Booking booking, UserPrincipal principal) {
        Trip trip = booking.getTrip();
        if (trip == null || trip.getCovoiturageOrganizer() == null
                || !trip.getCovoiturageOrganizer().getId().equals(principal.getUser().getId())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                    "Vous n'êtes pas l'organisateur de ce trajet covoiturage.");
        }
    }

    @Transactional
    public void confirmPayment(Long bookingId) {
        // 1. Récupération avec les détails (Jointures déjà optimisées)
        Booking booking = bookingRepository.findByIdWithDetails(bookingId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));
        enforceCanManageBooking(booking);

        // 2. Vérification du statut — PENDING (trajet public) ou AWAITING_PAYMENT
        // (covoiturage, après acceptation chauffeur)
        if (booking.getStatus() != BookingStatus.PENDING
                && booking.getStatus() != BookingStatus.AWAITING_PAYMENT) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Cette réservation est déjà confirmée ou annulée.");
        }
        if (booking.getStatus() == BookingStatus.AWAITING_PAYMENT
                && booking.getPaymentDeadline() != null
                && LocalDateTime.now().isAfter(booking.getPaymentDeadline())) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Le délai de paiement de 30 minutes est dépassé.");
        }

        // 3. LOGIQUE DE PAIEMENT (Wallet)
        User customer = booking.getCustomer();
        double amountToPay = booking.getTotalPrice();

        if (customer.getBalance() < amountToPay) {
            throw new MobiliException(MobiliErrorCode.INSUFFICIENT_BALANCE,
                    "Solde insuffisant dans votre portefeuille Mobili");
        }

        // Débit du solde
        customer.setBalance(customer.getBalance() - amountToPay);
        userRepository.save(customer);

        // 4. VALIDATION DE LA RÉSERVATION
        booking.setStatus(BookingStatus.CONFIRMED);
        booking.setPaidAt(LocalDateTime.now());
        booking = bookingRepository.save(booking);

        // Trip récupéré ici (avec Partner) pour permettre le calcul de la commission
        // compagnie pendant la génération des tickets ci-dessous.
        Trip fresh = tripRepository.findByIdWithPartnerAndStops(booking.getTrip().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));

        // 5. GÉNÉRATION SÉCURISÉE DES TICKETS (+ commission compagnie par ticket)
        generateTicketsWithCommission(booking, fresh.getPartner());

        tripRunService.ensureStops(fresh);
        tripRunService.refreshTripAvailableSeatsCounter(fresh);
        tripRepository.save(fresh);

        inboxNotificationService.notifyPartnerOnPaidBooking(booking);

        log.info("💰 Paiement réussi - Réservation: {} - Client: {}", booking.getId(), customer.getEmail());

        analyticsEventService.record(
                AnalyticsEventType.BOOKING_PAID,
                customer.getId(),
                String.format("{\"bookingId\":%d,\"source\":\"WALLET\"}", booking.getId()));
    }

    @Transactional(readOnly = true)
    public List<Booking> findByUserId(Long userId) {
        enforceCanReadUserBookings(userId);
        List<Booking> bookings = bookingRepository.findByCustomerIdOrderByBookingDateDesc(userId);
        bookings.forEach(this::initLazyCollections);
        return bookings;
    }

    @Transactional(readOnly = true)
    public List<Booking> findAll() {
        if (!isCurrentUserAdmin()) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Accès refusé à la liste globale des réservations");
        }
        List<Booking> bookings = bookingRepository.findAll();
        bookings.forEach(this::initLazyCollections);
        return bookings;
    }

    /**
     * Génère les tickets d'une réservation confirmée, avec commission compagnie par ticket —
     * partagé entre confirmPayment() (wallet) et confirmBookingAfterPayment() (Stripe/FedaPay),
     * les deux seuls points où un paiement est effectivement confirmé.
     *
     * La commission (voir CompanyCommissionService) est calculée sur transportFare + baggageFee
     * de CHAQUE ticket (jamais amountPaid, qui inclurait le forfait client — jamais reversé à
     * la compagnie). Le compteur mensuel (voir PartnerMonthlyVolumeService) n'avance qu'ici,
     * au moment de la confirmation du paiement — jamais à la simple création de la réservation.
     */
    private void generateTicketsWithCommission(Booking booking, Partner partner) {
        List<String> names = new ArrayList<>(booking.getPassengerNames());
        List<String> seats = new ArrayList<>(booking.getSeatNumbers());
        Collections.sort(names);
        Collections.sort(seats);

        int numberOfSeats = booking.getNumberOfSeats();
        double ticketsTotalAmount = booking.getTicketsTotalAmount() != null ? booking.getTicketsTotalAmount() : 0.0;
        int serviceFee = booking.getServiceFee() != null ? booking.getServiceFee() : 0;
        // luggageFee dérivé des champs déjà figés sur la réservation (pas recalculé depuis
        // trip.getExtraHoldBagPrice(), qui pourrait avoir changé depuis la création).
        double luggageFee = booking.getTotalPrice() - ticketsTotalAmount - serviceFee;

        double transportFarePerTicket = ticketsTotalAmount / numberOfSeats;
        double baggageFeePerTicket = luggageFee / numberOfSeats;

        List<Long> positions = partnerMonthlyVolumeService.reserveNextPositions(partner.getId(), names.size());

        for (int i = 0; i < names.size(); i++) {
            CommissionResult commission = companyCommissionService.calculateCommission(
                    transportFarePerTicket + baggageFeePerTicket, positions.get(i));
            ticketService.createFromBooking(booking, names.get(i), seats.get(i),
                    transportFarePerTicket, baggageFeePerTicket, commission, positions.get(i));
        }
    }

    /** Force l'initialisation des collections lazy avant la fermeture de la session. */
    private void initLazyCollections(Booking b) {
        if (b == null) return;
        if (b.getSeatNumbers() != null) b.getSeatNumbers().size();
        if (b.getPassengerNames() != null) b.getPassengerNames().size();
        if (b.getTrip() != null) b.getTrip().getDepartureCity();
        // Booking.getGrossAmount() lit les tickets pour exclure ceux ANNULÉ — sans ce
        // chargement ici (dans la transaction), l'appel plus tard (mapper/DTO) déclencherait
        // un LazyInitializationException ou un lazy-load hors session selon le contexte.
        if (b.getTickets() != null) b.getTickets().size();
    }

    @Transactional(readOnly = true)
    public List<String> getOccupiedSeatNumbers(Long tripId) {
        return getOccupiedSeatNumbers(tripId, null, null);
    }

    /**
     * Sièges indisponibles sur au moins un tronçon du segment demandé (union).
     * Si {@code boarding}/{@code alighting} sont null, union sur tout le parcours.
     */
    @Transactional(readOnly = true)
    public List<String> getOccupiedSeatNumbers(Long tripId, Integer boardingStopIndex, Integer alightingStopIndex) {
        Trip trip = tripService.findById(tripId);
        tripRunService.ensureStops(trip);
        int last = tripRunService.lastStopIndex(trip);
        int b = boardingStopIndex != null ? boardingStopIndex : 0;
        int a = alightingStopIndex != null ? alightingStopIndex : last;
        tripRunService.validateSegment(trip, b, a);
        Set<String> union = new HashSet<>();
        for (int leg = b; leg < a; leg++) {
            union.addAll(tripRunService.seatsOccupiedOnLeg(tripId, leg, last));
        }
        return new ArrayList<>(union).stream().sorted().collect(Collectors.toList());
    }

    @Transactional
    public void confirmBookingAfterPayment(Long bookingId) {
        // 1. Récupération
        Booking booking = bookingRepository.findByIdWithDetails(bookingId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));

        // 2. Vérification du statut — PENDING (trajet public) ou AWAITING_PAYMENT
        // (covoiturage, après acceptation chauffeur). Sans ce deuxième cas,
        // le paiement covoiturage était silencieusement ignoré ici.
        if (booking.getStatus() != BookingStatus.PENDING
                && booking.getStatus() != BookingStatus.AWAITING_PAYMENT) {
            log.warn("⚠️ Réservation {} déjà traitée. Statut actuel: {}", bookingId, booking.getStatus());
            return;
        }
        if (booking.getStatus() == BookingStatus.AWAITING_PAYMENT
                && booking.getPaymentDeadline() != null
                && LocalDateTime.now().isAfter(booking.getPaymentDeadline())) {
            log.warn("⚠️ Réservation {} : délai de paiement de 30 minutes dépassé.", bookingId);
            return;
        }

        // 3. LOGIQUE DE PAIEMENT EXTERNE (On ne touche pas au wallet ici)
        // L'argent est déjà chez le provider. On valide juste la commande.

        // 4. VALIDATION DE LA RÉSERVATION
        booking.setStatus(BookingStatus.CONFIRMED);
        booking.setPaidAt(LocalDateTime.now());
        booking = bookingRepository.save(booking);

        // Trip récupéré ici (avec Partner) pour permettre le calcul de la commission
        // compagnie pendant la génération des tickets ci-dessous.
        Trip fresh = tripRepository.findByIdWithPartnerAndStops(booking.getTrip().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));

        // 5. GÉNÉRATION DES TICKETS (+ commission compagnie par ticket)
        generateTicketsWithCommission(booking, fresh.getPartner());

        tripRunService.ensureStops(fresh);
        tripRunService.refreshTripAvailableSeatsCounter(fresh);
        tripRepository.save(fresh);

        log.info("✅ Paiement confirmé pour le Booking ID: {}", bookingId);

        inboxNotificationService.notifyPartnerOnPaidBooking(booking);

        analyticsEventService.record(
                AnalyticsEventType.BOOKING_PAID,
                booking.getCustomer().getId(),
                String.format("{\"bookingId\":%d,\"source\":\"PROVIDER\"}", bookingId));
    }

    @Transactional(readOnly = true)
    public Booking findById(Long id) {
        // On utilise la méthode avec JOIN FETCH pour charger trip et customer
        Booking booking = bookingRepository.findByIdWithDetails(id)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));
        enforceCanAccessBooking(booking);
        return booking;
    }

    @Transactional(readOnly = true)
    public List<Booking> findMyPartnerBookings() {
        Partner partner = partenaireService.getCurrentPartnerForOperations();
        Object p = getAuthenticatedPrincipal();
        Long stationId = stationIdOf(p);
        List<Booking> bookings;
        if (stationId != null) {
            bookings = bookingRepository.findAllByPartnerIdAndStationId(
                    partner.getId(), stationId);
        } else {
            bookings = bookingRepository.findAllByPartnerId(partner.getId());
        }
        bookings.forEach(this::initLazyCollections);
        return bookings;
    }

    public List<Booking> findMyPartnerBookingsInRange(LocalDate fromDate, LocalDate toDate, Long filterStationId) {
        Partner partner = partenaireService.getCurrentPartnerForOperations();
        Object p = getAuthenticatedPrincipal();
        Long principalStationId = stationIdOf(p);
        Long effectiveStationId = principalStationId != null ? principalStationId : filterStationId;

        LocalDateTime from = fromDate != null ? fromDate.atStartOfDay() : LocalDate.now().minusDays(29).atStartOfDay();
        LocalDateTime to = toDate != null ? toDate.atTime(23, 59, 59) : LocalDateTime.now();

        List<Booking> bookings = bookingRepository.findAllByPartnerIdAndOptionalStationIdAndDateRange(
                partner.getId(), effectiveStationId, from, to);
        bookings.forEach(this::initLazyCollections);
        return bookings;
    }

    /**
     * Transactions payées du partenaire connecté : vente brute (jamais le forfait client, qui
     * n'appartient jamais à la compagnie), commission prélevée par Mobili, net qui lui revient.
     * Même résolution de partenaire/gare que findMyPartnerBookingsInRange, réutilisée telle
     * quelle — seule la requête change (statuts payés + tickets fetch-joints).
     */
    @Transactional(readOnly = true)
    public List<com.mobili.backend.module.booking.booking.dto.PartnerTransactionResponse> findMyPartnerTransactionsInRange(
            LocalDate fromDate, LocalDate toDate, Long filterStationId) {
        Partner partner = partenaireService.getCurrentPartnerForOperations();
        Object p = getAuthenticatedPrincipal();
        Long principalStationId = stationIdOf(p);
        Long effectiveStationId = principalStationId != null ? principalStationId : filterStationId;

        LocalDateTime from = fromDate != null ? fromDate.atStartOfDay() : LocalDate.now().minusDays(29).atStartOfDay();
        LocalDateTime to = toDate != null ? toDate.atTime(23, 59, 59) : LocalDateTime.now();

        List<Booking> bookings = bookingRepository.findConfirmedForPartnerTransactions(
                partner.getId(), effectiveStationId, from, to);

        return bookings.stream()
                .map(b -> {
                    // Exclut les tickets ANNULÉ individuellement (annulation partielle) : sinon
                    // la commission d'un ticket annulé restait comptée alors que grossAmount
                    // (ci-dessous) ne le compte plus — décalage entre les deux colonnes.
                    int commissionTotal = b.getTickets().stream()
                            .filter(t -> t.getStatus() != TicketStatus.ANNULÉ)
                            .mapToInt(t -> t.getCommissionAmount() != null ? t.getCommissionAmount() : 0)
                            .sum();
                    // Seule implémentation de ce calcul dans tout le backend — voir
                    // Booking.getGrossAmount().
                    double grossAmount = b.getGrossAmount();
                    double companyNet = grossAmount - commissionTotal;

                    return new com.mobili.backend.module.booking.booking.dto.PartnerTransactionResponse(
                            b.getId(),
                            b.getReference(),
                            b.getBookingDate(),
                            b.getTrip() != null ? b.getTrip().getDepartureDateTime() : null,
                            com.mobili.backend.module.booking.booking.util.BookingSegmentUtil.resolveRouteLabel(b),
                            b.getTrip() != null && b.getTrip().getStation() != null
                                    ? b.getTrip().getStation().getName()
                                    : "—",
                            grossAmount,
                            commissionTotal,
                            companyNet,
                            b.getStatus() != null ? b.getStatus().name() : "—");
                })
                .toList();
    }

    @Transactional
    public void deactivateSeatsManually(ManualBlockRequest request) {
        Partner partner = partenaireService.getCurrentPartnerForOperations();
        Object principal = getAuthenticatedPrincipal();
        Trip trip = tripService.findById(request.getTripId());
        Long principalStationId = stationIdOf(principal);
        if (principalStationId != null) {
            if (trip.getStation() == null
                    || !trip.getStation().getId().equals(principalStationId)) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Hors périmètre de votre gare");
            }
        }
        if (!trip.getPartner().getId().equals(partner.getId())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Voyage d'un autre partenaire");
        }
        // Même verrou que create() — sérialise ce blocage manuel de sièges avec toute
        // réservation voyageur concurrente sur ce trajet.
        tripRunService.lockTrip(trip);
        tripRunService.ensureStops(trip);
        int last = tripRunService.lastStopIndex(trip);
        List<String> seatList = new ArrayList<>(request.getSeatNumbers());
        tripRunService.assertSeatsAvailableOnSegment(trip, 0, last, seatList);

        Booking block = new Booking();
        block.setTrip(trip);
        block.setCustomer(partner.getOwner());
        block.setSeatNumbers(request.getSeatNumbers());
        block.setNumberOfSeats(request.getSeatNumbers().size());
        block.setBoardingStopIndex(0);
        block.setAlightingStopIndex(last);

        block.setTotalPrice(0.0);
        block.setStatus(BookingStatus.OFFLINE_SALE);
        block.setBookingDate(LocalDateTime.now());
        block.setReference("GARE-" + System.currentTimeMillis() % 1000000);

        bookingRepository.save(block);

        Trip fresh = tripRepository.findByIdWithPartnerAndStops(trip.getId()).orElseThrow();
        tripRunService.ensureStops(fresh);
        tripRunService.refreshTripAvailableSeatsCounter(fresh);
        tripRepository.save(fresh);
    }

    private void enforceCanReadUserBookings(Long userId) {
        Object principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN") || hasAuthority(principal, "ROLE_STATION")) {
            return;
        }
        Long principalUserId = userIdOf(principal);
        if (principalUserId == null || !userId.equals(principalUserId)) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                    "Vous ne pouvez pas consulter les réservations d'un autre utilisateur");
        }
    }

    private void enforceCanManageBooking(Booking booking) {
        Object principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN")) {
            return;
        }
        Long userId = userIdOf(principal);
        if (hasAuthority(principal, "ROLE_PARTNER")
                && booking.getTrip() != null
                && booking.getTrip().getPartner() != null
                && booking.getTrip().getPartner().getOwner() != null
                && userId != null
                && userId.equals(booking.getTrip().getPartner().getOwner().getId())) {
            return;
        }
        if (hasAuthority(principal, "ROLE_GARE") || hasAuthority(principal, "ROLE_STATION")) {
            Long stationId = stationIdOf(principal);
            if (stationId != null
                    && booking.getTrip() != null
                    && booking.getTrip().getStation() != null
                    && booking.getTrip().getStation().getId().equals(stationId)) {
                return;
            }
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                "Vous ne pouvez pas confirmer cette réservation");
    }

    private void enforceCanAccessBooking(Booking booking) {
        Object principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN")) {
            return;
        }
        Long userId = userIdOf(principal);
        if (booking.getCustomer() != null && userId != null && userId.equals(booking.getCustomer().getId())) {
            return;
        }
        if (hasAuthority(principal, "ROLE_PARTNER")
                && booking.getTrip() != null
                && booking.getTrip().getPartner() != null
                && booking.getTrip().getPartner().getOwner() != null
                && userId != null
                && userId.equals(booking.getTrip().getPartner().getOwner().getId())) {
            return;
        }
        if (canGareAccessPartnerTrip(booking, principal)) {
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                "Vous ne pouvez pas accéder à cette réservation");
    }

    private boolean canGareAccessPartnerTrip(Booking booking, Object principal) {
        if (!(hasAuthority(principal, "ROLE_GARE") || hasAuthority(principal, "ROLE_STATION"))
                || booking.getTrip() == null) {
            return false;
        }
        Long stationId = stationIdOf(principal);
        if (stationId == null) {
            return false;
        }
        return booking.getTrip().getStation() != null
                && booking.getTrip().getStation().getId().equals(stationId);
    }

    private boolean isCurrentUserAdmin() {
        Object principal = getAuthenticatedPrincipal();
        return hasAuthority(principal, "ROLE_ADMIN");
    }

    private Object getAuthenticatedPrincipal() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || authentication.getPrincipal() == null) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Session invalide ou expirée");
        }
        return authentication.getPrincipal();
    }

    private static Long stationIdOf(Object principal) {
        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal sp) {
            return sp.getStationId();
        }
        if (principal instanceof UserPrincipal up) {
            return up.getStationId();
        }
        return null;
    }

    private static Long userIdOf(Object principal) {
        if (principal instanceof UserPrincipal up) {
            return up.getUser().getId();
        }
        return null;
    }

    private boolean hasAuthority(Object principal, String authority) {
        if (principal instanceof org.springframework.security.core.userdetails.UserDetails ud) {
            return ud.getAuthorities().stream()
                    .anyMatch(granted -> authority.equals(granted.getAuthority()));
        }
        return false;
    }

}
