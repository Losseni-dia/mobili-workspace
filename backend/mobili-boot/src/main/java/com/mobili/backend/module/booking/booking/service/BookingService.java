package com.mobili.backend.module.booking.booking.service;

import java.time.LocalDateTime;
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
import com.mobili.backend.module.booking.ticket.service.TicketService;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.service.TripPricingService;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

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
    private final InboxNotificationService inboxNotificationService;

    @Transactional
    public Booking create(BookingRequestDTO request) {
        Trip trip = tripService.findById(request.getTripId());
        User user = userService.findById(request.getUserId());
        int requestedSeats = request.getNumberOfSeats();

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
            throw new MobiliException(MobiliErrorCode.NO_SEATS_AVAILABLE, "Places insuffisantes sur une portion du trajet.");
        }

        double perSeatPrice = tripPricingService.resolvePricePerSeat(trip, boarding, alighting);

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
        double unitBagPrice = trip.getExtraHoldBagPrice() != null ? trip.getExtraHoldBagPrice() : 0.0;
        double luggageFee = extraBags * unitBagPrice;

        Booking booking = new Booking();
        booking.setTrip(trip);
        booking.setCustomer(user);
        booking.setNumberOfSeats(requestedSeats);
        booking.setTotalPrice(perSeatPrice * requestedSeats + luggageFee);
        booking.setExtraHoldBags(extraBags);
        booking.setBoardingStopIndex(boarding);
        booking.setAlightingStopIndex(alighting);
        booking.setStatus(BookingStatus.PENDING);

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

        return saved;
    }

    @Transactional
    public void confirmPayment(Long bookingId) {
        // 1. Récupération avec les détails (Jointures déjà optimisées)
        Booking booking = bookingRepository.findByIdWithDetails(bookingId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));
        enforceCanManageBooking(booking);

        // 2. Vérification du statut (Maintenant OK car Create s'arrête à PENDING)
        if (booking.getStatus() != BookingStatus.PENDING) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Cette réservation est déjà confirmée ou annulée.");
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

        // 5. GÉNÉRATION SÉCURISÉE DES TICKETS
        // Pour éviter que les noms et sièges ne se mélangent :
        List<String> names = new ArrayList<>(booking.getPassengerNames());
        List<String> seats = new ArrayList<>(booking.getSeatNumbers());

        // ✅ Optionnel mais recommandé : Tri pour garder une cohérence si les listes
        // ont été créées dans l'ordre alphabétique
        Collections.sort(names);
        Collections.sort(seats);

        for (int i = 0; i < names.size(); i++) {
            // Cette méthode crée le ticket physique que Maya scannera
            ticketService.createFromBooking(booking, names.get(i), seats.get(i));
        }

        Trip fresh = tripRepository.findByIdWithPartnerAndStops(booking.getTrip().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
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
        List<Booking> bookings = bookingRepository.findByCustomerId(userId);
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

    /** Force l'initialisation des collections lazy avant la fermeture de la session. */
    private void initLazyCollections(Booking b) {
        if (b == null) return;
        if (b.getSeatNumbers() != null) b.getSeatNumbers().size();
        if (b.getPassengerNames() != null) b.getPassengerNames().size();
        if (b.getTrip() != null) b.getTrip().getDepartureCity();
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

    // Dans BookingService.java

    @Transactional
    public void recordFedaPayTransactionId(Long bookingId, String fedapayTransactionId) {
        if (fedapayTransactionId == null || fedapayTransactionId.isBlank()) {
            return;
        }
        Booking booking = bookingRepository.findByIdWithDetails(bookingId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));
        enforceCanAccessBooking(booking);
        if (booking.getStatus() != BookingStatus.PENDING) {
            return;
        }
        booking.setFedapayTransactionId(fedapayTransactionId);
        bookingRepository.save(booking);
    }

    @Transactional
    public void confirmFedaPayPayment(Long bookingId) {
        // 1. Récupération
        Booking booking = bookingRepository.findByIdWithDetails(bookingId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réservation introuvable"));

        // 2. Vérification du statut
        if (booking.getStatus() != BookingStatus.PENDING) {
            log.warn("⚠️ Réservation {} déjà traitée. Statut actuel: {}", bookingId, booking.getStatus());
            return;
        }

        // 3. LOGIQUE DE PAIEMENT EXTERNE (On ne touche pas au wallet ici)
        // L'argent est déjà chez FedaPay. On valide juste la commande.

        // 4. VALIDATION DE LA RÉSERVATION
        booking.setStatus(BookingStatus.CONFIRMED);
        booking.setPaidAt(LocalDateTime.now());
        booking = bookingRepository.save(booking);

        // 5. GÉNÉRATION DES TICKETS (Réutilisation de ta logique existante)
        List<String> names = new ArrayList<>(booking.getPassengerNames());
        List<String> seats = new ArrayList<>(booking.getSeatNumbers());
        Collections.sort(names);
        Collections.sort(seats);

        for (int i = 0; i < names.size(); i++) {
            ticketService.createFromBooking(booking, names.get(i), seats.get(i));
        }

        Trip fresh = tripRepository.findByIdWithPartnerAndStops(booking.getTrip().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        tripRunService.ensureStops(fresh);
        tripRunService.refreshTripAvailableSeatsCounter(fresh);
        tripRepository.save(fresh);

        log.info("✅ Paiement FedaPay confirmé pour le Booking ID: {}", bookingId);

        inboxNotificationService.notifyPartnerOnPaidBooking(booking);

        analyticsEventService.record(
                AnalyticsEventType.BOOKING_PAID,
                booking.getCustomer().getId(),
                String.format("{\"bookingId\":%d,\"source\":\"FEDAPAY\"}", bookingId));
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
        UserPrincipal p = getAuthenticatedPrincipal();
        List<Booking> bookings;
        if (p.getStationId() != null) {
            bookings = bookingRepository.findAllByPartnerIdAndStationId(
                    partner.getId(), p.getStationId());
        } else {
            bookings = bookingRepository.findAllByPartnerId(partner.getId());
        }
        bookings.forEach(this::initLazyCollections);
        return bookings;
    }

    @Transactional
    public void deactivateSeatsManually(ManualBlockRequest request) {
        Partner partner = partenaireService.getCurrentPartnerForOperations();
        UserPrincipal principal = getAuthenticatedPrincipal();
        Trip trip = tripService.findById(request.getTripId());
        if (principal.getStationId() != null) {
            if (trip.getStation() == null
                    || !trip.getStation().getId().equals(principal.getStationId())) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Hors périmètre de votre gare");
            }
        }
        if (!trip.getPartner().getId().equals(partner.getId())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Voyage d'un autre partenaire");
        }
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
        UserPrincipal principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN")) {
            return;
        }
        if (!userId.equals(principal.getUser().getId())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                    "Vous ne pouvez pas consulter les réservations d'un autre utilisateur");
        }
    }

    private void enforceCanManageBooking(Booking booking) {
        UserPrincipal principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN")) {
            return;
        }
        if (hasAuthority(principal, "ROLE_PARTNER")
                && booking.getTrip() != null
                && booking.getTrip().getPartner() != null
                && booking.getTrip().getPartner().getOwner() != null
                && principal.getUser().getId().equals(booking.getTrip().getPartner().getOwner().getId())) {
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                "Vous ne pouvez pas confirmer cette réservation");
    }

    private void enforceCanAccessBooking(Booking booking) {
        UserPrincipal principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN")) {
            return;
        }
        if (booking.getCustomer() != null && principal.getUser().getId().equals(booking.getCustomer().getId())) {
            return;
        }
        if (hasAuthority(principal, "ROLE_PARTNER")
                && booking.getTrip() != null
                && booking.getTrip().getPartner() != null
                && booking.getTrip().getPartner().getOwner() != null
                && principal.getUser().getId().equals(booking.getTrip().getPartner().getOwner().getId())) {
            return;
        }
        if (canGareAccessPartnerTrip(booking, principal)) {
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                "Vous ne pouvez pas accéder à cette réservation");
    }

    private boolean canGareAccessPartnerTrip(Booking booking, UserPrincipal principal) {
        if (!hasAuthority(principal, "ROLE_GARE")
                || booking.getTrip() == null
                || principal.getStationId() == null) {
            return false;
        }
        return booking.getTrip().getStation() != null
                && booking.getTrip().getStation().getId().equals(principal.getStationId());
    }

    private boolean isCurrentUserAdmin() {
        UserPrincipal principal = getAuthenticatedPrincipal();
        return hasAuthority(principal, "ROLE_ADMIN");
    }

    private UserPrincipal getAuthenticatedPrincipal() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof UserPrincipal principal)) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Session invalide ou expirée");
        }
        return principal;
    }

    private boolean hasAuthority(UserPrincipal principal, String authority) {
        return principal.getAuthorities().stream()
                .anyMatch(granted -> authority.equals(granted.getAuthority()));
    }
}