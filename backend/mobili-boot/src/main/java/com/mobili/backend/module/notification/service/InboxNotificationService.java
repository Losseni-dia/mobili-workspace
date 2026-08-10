package com.mobili.backend.module.notification.service;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;
import com.mobili.backend.module.notification.dto.InboxNotificationResponseDTO;
import com.mobili.backend.module.notification.entity.MobiliInboxNotification;
import com.mobili.backend.module.notification.entity.MobiliNotificationType;
import com.mobili.backend.module.notification.entity.TripChannelMessage;
import com.mobili.backend.module.notification.event.InboxRefreshEvent;
import com.mobili.backend.module.notification.repository.MobiliInboxNotificationRepository;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class InboxNotificationService {

    private static final DateTimeFormatter FR = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
    private static final DateTimeFormatter FR_DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final MobiliInboxNotificationRepository inboxRepository;
    private final UserService userService;
    private final TicketRepository ticketRepository;
    private final TripRepository tripRepository;
    private final UserRepository userRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final FcmService fcmService;


    @Transactional
    public void notifyPassengerOnTicket(Ticket ticket) {
        if (ticket.getPassenger() == null) {
            return;
        }
        User recipient = userService.getReference(ticket.getPassenger().getId());
        Trip trip = ticket.getTrip();
        if (trip == null) {
            return;
        }
        String route = shortRoute(trip);
        String when = trip.getDepartureDateTime() != null ? trip.getDepartureDateTime().format(FR) : "";
        String title = "Billet prêt sur " + route;
        String pn = ticket.getPassengerName() != null ? ticket.getPassengerName() : "Passager";
        String sn = ticket.getSeatNumber() != null ? ticket.getSeatNumber() : "—";
        String body = "Votre billet n° " + ticket.getTicketNumber() + " est disponible. Passager " + pn
                + " — siège " + sn + (when.isEmpty() ? "" : " — départ le " + when);
        saveOne(recipient, MobiliNotificationType.TICKET_ISSUED, title, body, trip, null);
    }

    @Transactional
    public void notifyPartnerOnPaidBooking(Booking booking) {
        if (booking.getTrip() == null) {
            return;
        }
        Trip trip = tripRepository.findByIdWithPartnerAndStops(booking.getTrip().getId()).orElse(null);
        if (trip == null) {
            return;
        }
        Partner partner = trip.getPartner();
        String route = shortRoute(trip);
        String details = "Réservation n°" + booking.getId() + " : " + booking.getNumberOfSeats() + " place(s) sur "
                + route
                + " (client n°" + (booking.getCustomer() != null ? booking.getCustomer().getId() : "-") + ").";

        Long ownerId = null;
        if (partner != null && partner.getOwner() != null) {
            ownerId = partner.getOwner().getId();
            User owner = userService.getReference(ownerId);
            saveOne(owner, MobiliNotificationType.PARTNER_NEW_BOOKING, "Nouvelle réservation payée", details, trip,
                    null);
        }

        // Trajet covoiturage particulier : pas de partenaire/gare réels derrière
        // (partner = pool technique, station = null), donc l'organisateur ne
        // recevait jamais cette notification sans ce cas dédié.
        if (trip.getCovoiturageOrganizer() != null) {
            User organizer = userService.getReference(trip.getCovoiturageOrganizer().getId());
            saveOne(organizer, MobiliNotificationType.PARTNER_NEW_BOOKING, "Nouvelle réservation payée", details, trip,
                    null);
        }

        if (trip.getStation() != null) {
            String gareTitle = "Nouvelle réservation";
            String gareBody = details;
            saveOneForStation(trip.getStation(), MobiliNotificationType.GARE_STATION_NEW_BOOKING, gareTitle,
                    gareBody, trip, booking);
        }
    }
    
    /**
     * Nouvelle demande de réservation covoiturage — notifie le conducteur
     * organisateur du trajet, avec identité du demandeur (pas de données
     * sensibles : nom/prénom seulement, la photo est déjà accessible via
     * l'API profil du passager côté app).
     */
    @Transactional
    public void notifyDriverOnNewCovoiturageRequest(Booking booking) {
        Trip trip = booking.getTrip();
        if (trip == null || trip.getCovoiturageOrganizer() == null) {
            return;
        }
        User driver = userService.getReference(trip.getCovoiturageOrganizer().getId());
        String route = shortRoute(trip);
        String passengerName = fullName(booking.getCustomer());
        String title = "Nouvelle demande de réservation";
        String body = (passengerName == null || passengerName.isBlank() ? "Un voyageur" : passengerName)
                + " souhaite réserver " + booking.getNumberOfSeats() + " place(s) sur " + route
                + ". Vous avez 24h pour répondre.";
        saveOne(driver, MobiliNotificationType.COVOITURAGE_BOOKING_REQUEST, title, body, trip, null, booking);
    }

    /**
     * Décision du conducteur (accepté/refusé) sur une demande covoiturage —
     * notifie le passager demandeur.
     */
    @Transactional
    public void notifyPassengerOnCovoiturageDecision(Booking booking, boolean accepted) {
        if (booking.getCustomer() == null) {
            return;
        }
        User passenger = userService.getReference(booking.getCustomer().getId());
        Trip trip = booking.getTrip();
        String route = shortRoute(trip);
        String title = accepted ? "Demande acceptée ✅" : "Demande refusée";
        String body = accepted
                ? "Le conducteur a accepté votre demande sur " + route
                        + ". Vous avez 30 minutes pour finaliser le paiement."
                : "Le conducteur a refusé votre demande sur " + route + ".";
        MobiliNotificationType type = accepted
                ? MobiliNotificationType.COVOITURAGE_BOOKING_ACCEPTED
                : MobiliNotificationType.COVOITURAGE_BOOKING_REJECTED;
        saveOne(passenger, type, title, body, trip, null, booking);
    }

    /**
     * Scheduler : le conducteur n'a pas répondu dans les 24h — notifie le passager.
     */
    @Transactional
    public void notifyPassengerOnCovoiturageNoResponse(Booking booking) {
        if (booking.getCustomer() == null) {
            return;
        }
        User passenger = userService.getReference(booking.getCustomer().getId());
        Trip trip = booking.getTrip();
        String route = shortRoute(trip);
        String title = "Pas de réponse du conducteur";
        String body = "Le conducteur n'a pas répondu à votre demande sur " + route
                + " dans le délai imparti. Votre demande a expiré.";
        saveOne(passenger, MobiliNotificationType.COVOITURAGE_BOOKING_NO_RESPONSE, title, body, trip, null, booking);
    }

    /** Scheduler : le passager n'a pas payé dans les 30 min après acceptation. */
    @Transactional
    public void notifyPassengerOnCovoiturageBookingPaymentExpired(Booking booking) {
        if (booking.getCustomer() == null) {
            return;
        }
        User passenger = userService.getReference(booking.getCustomer().getId());
        Trip trip = booking.getTrip();
        String route = shortRoute(trip);
        String title = "Délai de paiement dépassé";
        String body = "Vous n'avez pas finalisé le paiement dans les 30 minutes sur " + route
                + ". La place a été libérée.";
        saveOne(passenger, MobiliNotificationType.COVOITURAGE_BOOKING_PAYMENT_EXPIRED, title, body, trip, null, booking);
    }

    @Transactional
    public void fanOutChannelMessage(Trip trip, TripChannelMessage message) {
        List<Long> ids = ticketRepository.findDistinctPassengerIdsWithActiveTicket(trip.getId());
        Long authorId = message.getAuthor() != null ? message.getAuthor().getId() : null;
        if (ids.isEmpty()) {
            return;
        }
        if (authorId != null) {
            ids = ids.stream().filter(uid -> !uid.equals(authorId)).toList();
        }
        if (ids.isEmpty()) {
            return;
        }
        String route = shortRoute(trip);
        String title = "Annonce voyage " + route;
        String name = message.getStation() != null
                ? "Gare " + message.getStation().getName()
                : fullName(message.getAuthor());
        String body = (name == null || name.isBlank() ? "Organisateur" : name) + " : " + message.getBody();
        List<MobiliInboxNotification> batch = new ArrayList<>();
        List<User> recipients = new ArrayList<>();
        for (Long uid : ids) {
            User recipient = userService.getReference(uid);
            recipients.add(recipient);
            MobiliInboxNotification n = new MobiliInboxNotification();
            n.setUser(recipient);
            n.setType(MobiliNotificationType.TRIP_CHANNEL_MESSAGE);
            n.setTitle(title);
            n.setBody(body);
            n.setTrip(trip);
            n.setSourceChannelMessage(message);
            batch.add(n);
        }
        inboxRepository.saveAll(batch);
        eventPublisher.publishEvent(new InboxRefreshEvent(new HashSet<>(ids)));
        for (User recipient : recipients) {
            if (recipient.getFcmToken() != null) {
                fcmService.sendToToken(recipient.getFcmToken(), title, body);
            }
        }
    }

    @Transactional
    public void markRead(Long id, Object principal) {
        MobiliInboxNotification n = inboxRepository.findById(id)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Notification introuvable"));
        Long stationId = stationIdOf(principal);
        if (stationId != null) {
            if (n.getStation() == null || !n.getStation().getId().equals(stationId)) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Accès refusé");
            }
        } else {
            Long userId = userIdOf(principal);
            if (userId == null || n.getUser() == null || !n.getUser().getId().equals(userId)) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Accès refusé");
            }
        }
        LocalDateTime now = LocalDateTime.now();
        n.setReadAt(now);
        if (n.getSeenAt() == null) {
            n.setSeenAt(now);
        }
        inboxRepository.save(n);
        if (stationId == null) {
            eventPublisher.publishEvent(new InboxRefreshEvent(Set.of(userIdOf(principal))));
        }
    }

    @Transactional
    public int markAllRead(Object principal) {
        Long stationId = stationIdOf(principal);
        if (stationId != null) {
            return inboxRepository.markAllReadForStation(stationId, LocalDateTime.now());
        }
        Long userId = userIdOf(principal);
        int updated = inboxRepository.markAllReadForUser(userId, LocalDateTime.now());
        eventPublisher.publishEvent(new InboxRefreshEvent(Set.of(userId)));
        return updated;
    }

    @Transactional(readOnly = true)
    public Page<InboxNotificationResponseDTO> listForUser(Object principal, Pageable pageable) {
        Long stationId = stationIdOf(principal);
        if (stationId != null) {
            return inboxRepository.findByStationIdOrderByCreatedAtDesc(stationId, pageable).map(this::toDto);
        }
        return inboxRepository
                .findByUserIdOrderByCreatedAtDesc(userIdOf(principal), pageable)
                .map(this::toDto);
    }

    @Transactional(readOnly = true)
    public long countUnread(Object principal) {
        Long stationId = stationIdOf(principal);
        if (stationId != null) {
            return inboxRepository.countByStationIdAndSeenAtIsNull(stationId);
        }
        return inboxRepository.countByUserIdAndSeenAtIsNull(userIdOf(principal));
    }

    /**
     * Vide le badge (pastille) sans marquer les notifications comme lues
     * individuellement.
     */
    @Transactional
    public int markAllSeen(Object principal) {
        Long stationId = stationIdOf(principal);
        if (stationId != null) {
            return inboxRepository.markAllSeenForStation(stationId, LocalDateTime.now());
        }
        return inboxRepository.markAllSeenForUser(userIdOf(principal), LocalDateTime.now());
    }

    private static Long userIdOf(Object principal) {
        if (principal instanceof UserPrincipal up) {
            return up.getUser().getId();
        }
        return null;
    }

    private static Long stationIdOf(Object principal) {
        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal sp) {
            return sp.getStationId();
        }
        return null;
    }

    @Transactional
    public void notifyCovoiturageKycExpiringSoon(User driver, LocalDate validUntil) {
        String when = validUntil.format(FR_DATE);
        String title = "CNI : expiration proche";
        String body = "Votre pièce d'identité expire le " + when
                + ". Un administrateur doit valider un renouvellement pour que vous puissiez continuer à proposer du covoiturage.";
        saveOne(driver, MobiliNotificationType.COV_KYC_EXPIRING_SOON, title, body, null, null);
    }

    @Transactional
    public void notifyCovoiturageKycExpired(User driver, LocalDate validUntil) {
        String when = validUntil.format(FR_DATE);
        String title = "CNI expirée — profil covoiturage";
        String body = "La date de fin de validité de votre pièce d'identité (" + when
                + ") est dépassée. Votre dossier est marqué à renouveler ; contactez le support ou l’administration.";
        saveOne(driver, MobiliNotificationType.COV_KYC_EXPIRED, title, body, null, null);
    }

    /**
     * Notifie tous les comptes administrateur (inbox métier).
     */
    @Transactional
    public void notifyAdmins(String title, String body, MobiliNotificationType type) {
        notifyAdmins(title, body, type, null, null);
    }

    @Transactional
    public void notifyAdmins(String title, String body, MobiliNotificationType type,
            com.mobili.backend.module.partner.entity.Partner partner) {
        notifyAdmins(title, body, type, partner, null);
    }

    /** Réclamation concernée : permet à l'admin d'ouvrir directement la bonne. */
    @Transactional
    public void notifyAdmins(String title, String body, MobiliNotificationType type,
            com.mobili.backend.module.claim.entity.Claim claim) {
        notifyAdmins(title, body, type, null, claim);
    }

    private void notifyAdmins(String title, String body, MobiliNotificationType type,
            com.mobili.backend.module.partner.entity.Partner partner,
            com.mobili.backend.module.claim.entity.Claim claim) {
        List<User> admins = userRepository.findUsersWithAdminRole();
        Set<Long> adminIds = new HashSet<>();
        for (User a : admins) {
            MobiliInboxNotification n = new MobiliInboxNotification();
            n.setUser(a);
            n.setType(type);
            n.setTitle(title);
            n.setBody(body);
            n.setPartner(partner);
            n.setClaim(claim);
            inboxRepository.save(n);
            adminIds.add(a.getId());
            if (a.getFcmToken() != null) {
                fcmService.sendToToken(a.getFcmToken(), title, body);
            }
        }
        if (!adminIds.isEmpty()) {
            eventPublisher.publishEvent(new InboxRefreshEvent(adminIds));
        }
    }


    @Transactional
    public void notifyUser(User user, String title, String body, MobiliNotificationType type) {
        saveOne(user, type, title, body, null, null);
    }

    /** Réclamation concernée : permet au passager d'ouvrir directement la bonne. */
    @Transactional
    public void notifyUser(User user, String title, String body, MobiliNotificationType type,
            com.mobili.backend.module.claim.entity.Claim claim) {
        MobiliInboxNotification n = new MobiliInboxNotification();
        n.setUser(user);
        n.setType(type);
        n.setTitle(title);
        n.setBody(body);
        n.setClaim(claim);
        inboxRepository.save(n);
        eventPublisher.publishEvent(new InboxRefreshEvent(Set.of(user.getId())));
        if (user.getFcmToken() != null) {
            fcmService.sendToToken(user.getFcmToken(), title, body);
        }
    }

    /**
     * Messages d’information Mobili (admin) vers l’inbox des dirigeants partenaire.
     * @return nombre de comptes notifiés
     */
    @Transactional
    public int notifyPartnerOwnersInfoFromAdmin(java.util.Set<Long> ownerUserIds, String title, String body) {
        if (ownerUserIds == null || ownerUserIds.isEmpty()) {
            return 0;
        }
        if (title == null || title.isBlank() || body == null || body.isBlank()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Titre et message sont requis.");
        }
        int n = 0;
        for (Long uid : ownerUserIds) {
            saveOne(
                    userService.getReference(uid),
                    MobiliNotificationType.MOBILI_ADMIN_INFO_PARTNER,
                    title.trim(),
                    body.trim(),
                    null,
                    null);
            n++;
        }
        return n;
    }

    @Transactional
    public void notifyPartnerGareCom(User recipient,
            com.mobili.backend.module.partnergarecom.entity.PartnerGareComThread thread,
            String title,
            String bodyPreview) {
        MobiliInboxNotification n = new MobiliInboxNotification();
        n.setUser(userService.getReference(recipient.getId()));
        n.setType(MobiliNotificationType.PARTNER_GARE_COM_MESSAGE);
        n.setTitle(title);
        n.setBody(bodyPreview);
        n.setPartnerGareComThread(thread);
        n.setTrip(null);
        n.setSourceChannelMessage(null);
        inboxRepository.save(n);
        eventPublisher.publishEvent(new InboxRefreshEvent(Set.of(recipient.getId())));
        if (recipient.getFcmToken() != null) {
            fcmService.sendToToken(recipient.getFcmToken(), title, bodyPreview);
        }
    }

    /**
     * Variante ciblant directement une gare (StationPrincipal), plus utilisée via
     * un compte chef de gare.
     */
    @Transactional
    public void notifyPartnerGareComForStation(com.mobili.backend.module.station.entity.Station station,
            com.mobili.backend.module.partnergarecom.entity.PartnerGareComThread thread,
            String title,
            String bodyPreview) {
        MobiliInboxNotification n = new MobiliInboxNotification();
        n.setStation(station);
        n.setType(MobiliNotificationType.PARTNER_GARE_COM_MESSAGE);
        n.setTitle(title);
        n.setBody(bodyPreview);
        n.setPartnerGareComThread(thread);
        inboxRepository.save(n);
        if (station.getFcmToken() != null) {
            fcmService.sendToToken(station.getFcmToken(), title, bodyPreview);
        }
    }

    private void saveOne(User user, MobiliNotificationType type, String title, String body, Trip trip,
            TripChannelMessage link) {
        saveOne(user, type, title, body, trip, link, null);
    }

    private void saveOne(User user, MobiliNotificationType type, String title, String body, Trip trip,
            TripChannelMessage link, com.mobili.backend.module.booking.booking.entity.Booking booking) {
        MobiliInboxNotification n = new MobiliInboxNotification();
        n.setUser(user);
        n.setType(type);
        n.setTitle(title);
        n.setBody(body);
        n.setTrip(trip);
        n.setSourceChannelMessage(link);
        n.setBooking(booking);
        inboxRepository.save(n);
        eventPublisher.publishEvent(new InboxRefreshEvent(Set.of(user.getId())));
        // Push FCM
        if (user.getFcmToken() != null) {
            fcmService.sendToToken(user.getFcmToken(), title, body);
        }
    }

    /**
     * Notification ciblant directement une gare (StationPrincipal), pas un compte
     * utilisateur.
     */
    private void saveOneForStation(com.mobili.backend.module.station.entity.Station station,
            MobiliNotificationType type, String title, String body, Trip trip,
            com.mobili.backend.module.booking.booking.entity.Booking booking) {
        MobiliInboxNotification n = new MobiliInboxNotification();
        n.setStation(station);
        n.setType(type);
        n.setTitle(title);
        n.setBody(body);
        n.setTrip(trip);
        n.setBooking(booking);
        inboxRepository.save(n);
        if (station.getFcmToken() != null) {
            fcmService.sendToToken(station.getFcmToken(), title, body);
        }
    }


    private InboxNotificationResponseDTO toDto(MobiliInboxNotification n) {
        Optional<Trip> t = Optional.ofNullable(n.getTrip());
        return InboxNotificationResponseDTO.builder()
                .id(n.getId())
                .type(n.getType())
                .title(n.getTitle())
                .body(n.getBody())
                .read(n.getReadAt() != null)
                .createdAt(n.getCreatedAt())
                .tripId(t.map(Trip::getId).orElse(null))
                .tripRoute(t.map(this::shortRoute).orElse(null))
                .bookingId(n.getBooking() == null ? null : n.getBooking().getId())
                .channelMessageId(
                        n.getSourceChannelMessage() == null ? null : n.getSourceChannelMessage().getId())
                .partnerGareComThreadId(
                        n.getPartnerGareComThread() == null ? null : n.getPartnerGareComThread().getId())
                .partnerId(n.getPartner() == null ? null : n.getPartner().getId())
                .claimId(n.getClaim() == null ? null : n.getClaim().getId())
                .build();
    }

    private String shortRoute(Trip trip) {
        if (trip == null) {
            return "";
        }
        String a = nullToEmpty(trip.getDepartureCity());
        String b = nullToEmpty(trip.getArrivalCity());
        if (a.isEmpty() && b.isEmpty()) {
            return "trajet";
        }
        return a + " → " + b;
    }

    private String nullToEmpty(String s) {
        return s == null ? "" : s.trim();
    }

    private String fullName(User u) {
        if (u == null) {
            return null;
        }
        String a = nullToEmpty(u.getFirstname());
        String c = nullToEmpty(u.getLastname());
        return (a + " " + c).trim();
    }

  @Transactional
    public void delete(Long id, Object principal) {
        MobiliInboxNotification n = inboxRepository.findById(id)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Notification introuvable"));
        Long stationId = stationIdOf(principal);
        if (stationId != null) {
            if (n.getStation() == null || !n.getStation().getId().equals(stationId)) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Accès refusé");
            }
        } else {
            Long userId = userIdOf(principal);
            if (userId == null || n.getUser() == null || !n.getUser().getId().equals(userId)) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Accès refusé");
            }
        }
        inboxRepository.delete(n);
    }

    @Transactional
    public void deleteAll(Object principal) {
        Long stationId = stationIdOf(principal);
        if (stationId != null) {
            inboxRepository.deleteAllByStationId(stationId);
            return;
        }
        inboxRepository.deleteAllByUserId(userIdOf(principal));
    }
}