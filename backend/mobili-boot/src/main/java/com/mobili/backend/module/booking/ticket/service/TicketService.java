package com.mobili.backend.module.booking.ticket.service;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.entity.TicketStatus;
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

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
        Ticket ticket = new Ticket();
        ticket.setBooking(booking);
        ticket.setTrip(booking.getTrip());
        ticket.setPassenger(booking.getCustomer());
        ticket.setPassengerName(name);
        ticket.setSeatNumber(seatNumber);
        double paid = booking.getTotalPrice() / Math.max(1, booking.getNumberOfSeats());
        ticket.setAmountPaid(paid);
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

        UserPrincipal principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_GARE")) {
            Trip trip = ticket.getTrip();
            if (trip.getStation() == null
                    || principal.getStationId() == null
                    || !trip.getStation().getId().equals(principal.getStationId())) {
                throw new MobiliException(
                        MobiliErrorCode.ACCESS_DENIED,
                        "Ce billet ne correspond pas à l’embarquement géré par votre gare.");
            }
        } else if (!hasAuthority(principal, "ROLE_ADMIN")
                && hasAuthority(principal, "ROLE_CHAUFFEUR")) {
            Trip trip = ticket.getTrip();
            if (trip.getCovoiturageOrganizer() != null) {
                if (!trip.getCovoiturageOrganizer().getId().equals(principal.getUser().getId())) {
                    throw new MobiliException(
                            MobiliErrorCode.ACCESS_DENIED,
                            "Ce billet n’est pas lié à un de vos trajets covoiturage.");
                }
            } else {
                Long userPartnerId = principal.getPartnerId();
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
     * Confirmation de descente par le chauffeur : libère le siège sur les tronçons suivants.
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
        UserPrincipal principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN")) {
            return;
        }
        if (!userId.equals(principal.getUser().getId())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                    "Vous ne pouvez pas consulter les tickets d'un autre utilisateur");
        }
    }

    private void enforceCanAccessTicket(Ticket ticket) {
        UserPrincipal principal = getAuthenticatedPrincipal();
        if (hasAuthority(principal, "ROLE_ADMIN")) {
            return;
        }
        if (ticket.getPassenger() != null && principal.getUser().getId().equals(ticket.getPassenger().getId())) {
            return;
        }
        if (hasAuthority(principal, "ROLE_PARTNER")
                && ticket.getTrip() != null
                && ticket.getTrip().getPartner() != null
                && ticket.getTrip().getPartner().getOwner() != null
                && principal.getUser().getId().equals(ticket.getTrip().getPartner().getOwner().getId())) {
            return;
        }
        if (hasAuthority(principal, "ROLE_GARE")
                && ticket.getTrip() != null
                && ticket.getTrip().getStation() != null
                && principal.getStationId() != null
                && ticket.getTrip().getStation().getId().equals(principal.getStationId())) {
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                "Vous ne pouvez pas annuler ce ticket");
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