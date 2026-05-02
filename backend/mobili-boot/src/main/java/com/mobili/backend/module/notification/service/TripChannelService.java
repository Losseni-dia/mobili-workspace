package com.mobili.backend.module.notification.service;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;
import com.mobili.backend.module.notification.dto.PostChannelMessageRequestDTO;
import com.mobili.backend.module.notification.dto.TripChannelMessageResponseDTO;
import com.mobili.backend.module.notification.entity.TripChannelMessage;
import com.mobili.backend.module.notification.repository.TripChannelMessageRepository;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class TripChannelService {

    private final TripRepository tripRepository;
    private final TripChannelMessageRepository messageRepository;
    private final TicketRepository ticketRepository;
    private final UserService userService;
    private final InboxNotificationService inboxNotificationService;

    @Transactional
    public TripChannelMessageResponseDTO postMessage(Long tripId, PostChannelMessageRequestDTO req, UserPrincipal principal) {
        String body = req.getBody() == null ? "" : req.getBody().strip();
        if (body.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Le message ne peut pas être vide.");
        }
        Trip trip = tripRepository.findByIdWithPartnerAndStops(tripId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        assertCanPost(trip, principal);
        User author = userService.findById(principal.getUser().getId());
        TripChannelMessage m = new TripChannelMessage();
        m.setTrip(trip);
        m.setAuthor(author);
        m.setBody(body);
        TripChannelMessage saved = messageRepository.save(m);
        inboxNotificationService.fanOutChannelMessage(trip, saved);
        return toDto(saved);
    }

    @Transactional(readOnly = true)
    public List<TripChannelMessageResponseDTO> listMessages(Long tripId, UserPrincipal principal) {
        assertCanView(tripId, principal);
        return messageRepository.findByTripIdOrderByCreatedAtAsc(tripId).stream()
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    private void assertCanView(Long tripId, UserPrincipal p) {
        Trip trip = tripRepository.findByIdWithPartnerAndStops(tripId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        if (isAdmin(p)) {
            return;
        }
        if (isPartnerForTrip(trip, p) || isGareForTrip(trip, p)) {
            return;
        }
        if (ticketRepository.existsActiveTicketForTripAndPassenger(tripId, p.getUser().getId())) {
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Vous n'avez pas accès à ce fil de messages.");
    }

    private void assertCanPost(Trip trip, UserPrincipal p) {
        if (isAdmin(p)) {
            return;
        }
        if (isPartnerForTrip(trip, p) || isGareForTrip(trip, p)) {
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                "Seuls le partenaire, la gare concernée ou un administrateur peuvent publier ici.");
    }

    private boolean isAdmin(UserPrincipal p) {
        return p.getAuthorities().stream().anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
    }

    private boolean isPartnerForTrip(Trip trip, UserPrincipal p) {
        if (p.getPartnerId() == null || trip.getPartner() == null) {
            return false;
        }
        return p.getPartnerId().equals(trip.getPartner().getId())
                && hasRole(p, "ROLE_PARTNER");
    }

    private boolean isGareForTrip(Trip trip, UserPrincipal p) {
        if (p.getStationId() == null || trip.getStation() == null) {
            return false;
        }
        return p.getStationId().equals(trip.getStation().getId())
                && hasRole(p, "ROLE_GARE");
    }

    private boolean hasRole(UserPrincipal p, String role) {
        return p.getAuthorities().stream().map(GrantedAuthority::getAuthority).toList().contains(role);
    }

    private TripChannelMessageResponseDTO toDto(TripChannelMessage m) {
        User a = m.getAuthor();
        String name = a == null ? "?" : (nullTo(a.getFirstname()) + " " + nullTo(a.getLastname())).strip();
        if (name.isEmpty()) {
            name = a.getLogin() != null ? a.getLogin() : "?";
        }
        String r = a != null && a.getRoles() != null && !a.getRoles().isEmpty()
                ? a.getRoles().iterator().next().getName().name()
                : "";
        return TripChannelMessageResponseDTO.builder()
                .id(m.getId())
                .body(m.getBody())
                .createdAt(m.getCreatedAt())
                .authorName(name)
                .authorRole(r)
                .build();
    }

    private String nullTo(String s) {
        return s == null ? "" : s.trim();
    }
}
