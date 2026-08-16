package com.mobili.backend.module.booking.ticket.service;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.entity.TicketStatus;
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.pricing.dto.CommissionResult;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
@Slf4j
@RequiredArgsConstructor
public class TicketService {

    private final TicketRepository ticketRepository;
    private final TripService tripService;
    private final TripRepository tripRepository;
    private final UserService userService;
    private final TripRunService tripRunService;
    private final InboxNotificationService inboxNotificationService;

    @Transactional(readOnly = true)
    public List<Ticket> findAllByTripId(Long tripId) {
        List<Ticket> tickets = ticketRepository.findAllByTripIdOrderBySeatNumberAsc(tripId);
        // ASTUCE : on force Hibernate à charger ces associations lazy avant la fin de
        // la
        // transaction, car le mapping vers TicketResponseDTO se fait hors session (dans
        // le controller).
        for (Ticket t : tickets) {
            if (t.getTrip() != null) {
                t.getTrip().getDepartureCity();
            }
            if (t.getBooking() != null
                    && t.getBooking().getTrip() != null
                    && t.getBooking().getTrip().getPartner() != null) {
                t.getBooking().getTrip().getPartner().getName();
            }
        }
        return tickets;
    }

    /**
     * Tickets liés à UNE réservation (bouton "Voir tickets/voyageurs" côté partenaire, sur
     * Mes réservations) — même astuce de pré-chargement lazy que {@link #findAllByTripId}.
     */
    @Transactional(readOnly = true)
    public List<Ticket> findAllByBookingId(Long bookingId) {
        List<Ticket> tickets = ticketRepository.findAllByBookingIdOrderBySeatNumberAsc(bookingId);
        for (Ticket t : tickets) {
            if (t.getTrip() != null) {
                t.getTrip().getDepartureCity();
            }
            if (t.getBooking() != null
                    && t.getBooking().getTrip() != null
                    && t.getBooking().getTrip().getPartner() != null) {
                t.getBooking().getTrip().getPartner().getName();
            }
        }
        return tickets;
    }

    @Transactional
    public Ticket create(Long tripId, Long userId) {
        Trip trip = tripService.findById(tripId);
        User user = userService.findById(userId);

        tripRunService.ensureStops(trip);
        int last = tripRunService.lastStopIndex(trip);
        if (tripRunService.minFreeSeatsOnSegment(trip, 0, last) < 1) {
            throw new MobiliException(
                    MobiliErrorCode.NO_SEATS_AVAILABLE,
                    "Désolé, toutes les places pour ce trajet ont été vendues.");
        }

        Ticket ticket = new Ticket();
        ticket.setTrip(trip);
        ticket.setPassenger(user);
        ticket.setAmountPaid(trip.getPrice());
        ticket.setStatus(TicketStatus.VALIDÉ);
        ticket.setBoardingStopIndex(0);
        ticket.setAlightingStopIndex(last);

        Ticket saved = ticketRepository.save(ticket);
        tripRunService.ensureStops(trip);
        tripRunService.refreshTripAvailableSeatsCounter(trip);
        tripRepository.save(trip);
        inboxNotificationService.notifyPassengerOnTicket(saved);
        return saved;
    }

    @Transactional
    public void createFromBooking(Booking booking, String name, String seatNumber) {
        createFromBooking(booking, name, seatNumber, null, null, null, null);
    }

    /**
     * Variante enrichie avec la décomposition tarifaire utilisée pour la commission
     * compagnie (voir CompanyCommissionService/BookingService.generateTicketsWithCommission) —
     * transportFare/baggageFee restent des champs distincts, jamais fusionnés dans amountPaid.
     */
    @Transactional
    public void createFromBooking(Booking booking, String name, String seatNumber,
            Double transportFare, Double baggageFee, CommissionResult commission, Long monthlySequenceNumber) {
        Ticket ticket = new Ticket();
        ticket.setBooking(booking);
        ticket.setTrip(booking.getTrip());
        ticket.setPassenger(booking.getCustomer());
        ticket.setPassengerName(name);
        ticket.setSeatNumber(seatNumber);
        double paid = booking.getTotalPrice() / Math.max(1, booking.getNumberOfSeats());
        ticket.setAmountPaid(paid);
        ticket.setTransportFare(transportFare);
        ticket.setBaggageFee(baggageFee);
        if (commission != null) {
            ticket.setCommissionRate(commission.rate());
            ticket.setCommissionAmount(commission.amount());
        }
        if (monthlySequenceNumber != null) {
            ticket.setMonthlySequenceNumber(monthlySequenceNumber.intValue());
        }
        int last = tripRunService.lastStopIndex(booking.getTrip());
        ticket.setBoardingStopIndex(Optional.ofNullable(booking.getBoardingStopIndex()).orElse(0));
        ticket.setAlightingStopIndex(Optional.ofNullable(booking.getAlightingStopIndex()).orElse(last));

        // GENERATION DU NUMERO DE TICKET UNIQUE
        // Exemple : MOB-ID_BOOKING-ALEATOIRE (ex: MOB-26-X8R)
        String uniqueCode = "MOB-" + booking.getId() + "-"
                + java.util.UUID.randomUUID().toString().substring(0, 5).toUpperCase();
        ticket.setTicketNumber(uniqueCode);

        ticket.setBookingDate(LocalDateTime.now());
        ticket.setStatus(TicketStatus.VALIDÉ);

        ticketRepository.save(ticket);
        log.info("Ticket créé : {} | N°: {} | Siège: {}", name, uniqueCode, seatNumber);
        inboxNotificationService.notifyPassengerOnTicket(ticket);
    }

    @Transactional(readOnly = true)
    public List<Ticket> findAllByUserId(Long userId) {
        enforceCanReadUserTickets(userId);
        return ticketRepository.findAllByUserIdCustom(userId);
    }

    @Transactional
    public void cancelTicket(Long ticketId) {
        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Ticket introuvable"));
        enforceCanAccessTicket(ticket);

        // Utilisation de ton code BKG-001
        if (ticket.getStatus() == TicketStatus.ANNULÉ) {
            throw new MobiliException(MobiliErrorCode.BOOKING_ALREADY_CANCELLED, "Ce ticket est déjà annulé.");
        }

        if (ticket.getStatus() == TicketStatus.VALIDÉ) {
            ticket.setStatus(TicketStatus.ANNULÉ);

            // On rend la place au voyage
            Trip trip = ticket.getTrip();
            tripRepository.save(trip);

            ticketRepository.save(ticket);
            tripRunService.ensureStops(trip);
            tripRunService.refreshTripAvailableSeatsCounter(trip);
            tripRepository.save(trip);
        }
    }

    @Transactional
    public Ticket verifyAndUseTicket(String ticketNumber) {
        // 1. Recherche du ticket
        Ticket ticket = ticketRepository.findByTicketNumber(ticketNumber)
                .orElseThrow(() -> new MobiliException(
                        MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Ticket invalide ou inexistant."));

        // 2. Vérification avec tes codes d'erreurs métier
        if (ticket.getStatus() == TicketStatus.UTILISÉ) {
            throw new MobiliException(
                    MobiliErrorCode.TICKET_ALREADY_USED,
                    "Alerte : Ce ticket a déjà été scanné à l'embarquement.");
        }

        if (ticket.getStatus() == TicketStatus.ANNULÉ) {
            throw new MobiliException(
                    MobiliErrorCode.TICKET_CANCELLED,
                    "Accès refusé : Ce ticket a été annulé par le client ou le système.");
        }
        if (ticket.getTrip().getDepartureDateTime().isBefore(LocalDateTime.now().minusHours(1))) {
            throw new MobiliException(
                    MobiliErrorCode.TICKET_EXPIRED,
                    "Ce ticket a expiré car la date du voyage est passée.");
        }

        Object principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_GARE") || hasAuthority(principal, "ROLE_STATION")) {
            Trip trip = ticket.getTrip();
            Long principalStationId = stationIdOf(principal);
            if (trip.getStation() == null
                    || principalStationId == null
                    || !trip.getStation().getId().equals(principalStationId)) {
                throw new MobiliException(
                        MobiliErrorCode.ACCESS_DENIED,
                        "Ce billet ne correspond pas à l’embarquement géré par votre gare.");
            }
        } else if (!hasAuthority(principal, "ROLE_ADMIN")
                && hasAuthority(principal, "ROLE_CHAUFFEUR")) {
            Trip trip = ticket.getTrip();
            if (trip.getCovoiturageOrganizer() != null) {
                Long chauffeurUserId = userIdOf(principal);
                if (chauffeurUserId == null
                        || !trip.getCovoiturageOrganizer().getId().equals(chauffeurUserId)) {
                    throw new MobiliException(
                            MobiliErrorCode.ACCESS_DENIED,
                            "Ce billet n’est pas lié à un de vos trajets covoiturage.");
                }
            } else {
                Long userPartnerId = partnerIdOf(principal);
                if (userPartnerId == null || !userPartnerId.equals(trip.getPartner().getId())) {
                    throw new MobiliException(
                            MobiliErrorCode.ACCESS_DENIED,
                            "Ce billet n’est pas pour un trajet de votre compagnie.");
                }
            }
        }

        // 3. Validation du passage (montée)
        ticket.setStatus(TicketStatus.UTILISÉ);
        ticket.setScanned(true);
        ticket.setScannedAt(LocalDateTime.now());
        return ticketRepository.save(ticket);
    }

    /**
     * Confirmation de descente par le chauffeur : libère le siège sur les tronçons
     * suivants.
     */
    @Transactional
    public Ticket confirmPassengerAlightedAtStop(Long tripId, String ticketNumber, Integer stopIndexOrNull) {
        Ticket ticket = ticketRepository.findByTicketNumber(ticketNumber)
                .orElseThrow(() -> new MobiliException(
                        MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Ticket invalide ou inexistant."));
        if (!ticket.getTrip().getId().equals(tripId)) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Ce ticket ne correspond pas à ce voyage.");
        }
        if (ticket.getStatus() == TicketStatus.ANNULÉ) {
            throw new MobiliException(MobiliErrorCode.TICKET_CANCELLED, "Ticket annulé.");
        }
        Trip tripRef = ticket.getTrip();
        tripRunService.ensureStops(tripRef);
        int plannedAlight = Optional.ofNullable(ticket.getAlightingStopIndex())
                .orElse(tripRunService.lastStopIndex(tripRef));
        int stop = stopIndexOrNull != null ? stopIndexOrNull : plannedAlight;
        if (stopIndexOrNull != null && !stopIndexOrNull.equals(plannedAlight)) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "La descente doit être enregistrée à l’arrêt prévu sur le billet.");
        }
        if (ticket.getAlightedAtStopIndex() != null) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Descente déjà enregistrée pour ce ticket.");
        }
        ticket.setAlightedAtStopIndex(stop);
        ticket.setAlightedAt(LocalDateTime.now());
        if (ticket.getStatus() == TicketStatus.UTILISÉ) {
            ticket.setStatus(TicketStatus.ARRIVÉ);
        }
        Ticket saved = ticketRepository.save(ticket);

        Trip trip = tripRepository.findByIdWithPartnerAndStops(tripId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        tripRunService.ensureStops(trip);
        tripRunService.refreshTripAvailableSeatsCounter(trip);
        tripRepository.save(trip);
        return saved;
    }

    @Transactional(readOnly = true)
    public List<String> getOccupiedSeatsForTrip(Long tripId) {
        // Cette méthode doit appeler un nouveau findOccupiedSeats dans ton Repository
        return ticketRepository.findOccupiedSeatNumbersByTripId(tripId);
    }

    private void enforceCanReadUserTickets(Long userId) {
        Object principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN") || hasAuthority(principal, "ROLE_STATION")) {
            return;
        }
        Long principalUserId = userIdOf(principal);
        if (principalUserId == null || !userId.equals(principalUserId)) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                    "Vous ne pouvez pas consulter les tickets d'un autre utilisateur");
        }
    }

    private void enforceCanAccessTicket(Ticket ticket) {
        Object principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN")) {
            return;
        }
        Long principalUserId = userIdOf(principal);
        if (ticket.getPassenger() != null && principalUserId != null
                && principalUserId.equals(ticket.getPassenger().getId())) {
            return;
        }
        if (hasAuthority(principal, "ROLE_PARTNER")
                && ticket.getTrip() != null
                && ticket.getTrip().getPartner() != null
                && ticket.getTrip().getPartner().getOwner() != null
                && principalUserId != null
                && principalUserId.equals(ticket.getTrip().getPartner().getOwner().getId())) {
            return;
        }
        if ((hasAuthority(principal, "ROLE_GARE") || hasAuthority(principal, "ROLE_STATION"))
                && ticket.getTrip() != null
                && ticket.getTrip().getStation() != null
                && stationIdOf(principal) != null
                && ticket.getTrip().getStation().getId().equals(stationIdOf(principal))) {
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                "Vous ne pouvez pas annuler ce ticket");
    }

    private Object getAuthenticatedPrincipal() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || authentication.getPrincipal() == null) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Session invalide ou expirée");
        }
        return authentication.getPrincipal();
    }

    private boolean hasAuthority(Object principal, String authority) {
        if (principal instanceof org.springframework.security.core.userdetails.UserDetails ud) {
            return ud.getAuthorities().stream()
                    .anyMatch(granted -> authority.equals(granted.getAuthority()));
        }
        return false;
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

    private static Long partnerIdOf(Object principal) {
        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal sp) {
            return sp.getPartnerId();
        }
        if (principal instanceof UserPrincipal up) {
            return up.getPartnerId();
        }
        return null;
    }
}