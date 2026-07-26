package com.mobili.backend.module.notification.service;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;
import com.mobili.backend.module.notification.dto.PostChannelMessageRequestDTO;
import com.mobili.backend.module.notification.dto.TripChannelMessageResponseDTO;
import com.mobili.backend.module.notification.entity.TripChannelMessage;
import com.mobili.backend.module.notification.repository.TripChannelMessageRepository;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

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
    private final PartnerService partnerService;
    private final InboxNotificationService inboxNotificationService;

    @Transactional
    public TripChannelMessageResponseDTO postMessage(Long tripId, PostChannelMessageRequestDTO req, Object principal) {
        String body = req.getBody() == null ? "" : req.getBody().strip();
        if (body.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Le message ne peut pas être vide.");
        }
        Trip trip = tripRepository.findByIdWithPartnerAndStops(tripId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        assertCanPost(trip, principal);

        User author;
        com.mobili.backend.module.station.entity.Station postingStation = null;
        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal sp) {
            // Une gare n'a pas de compte User propre : le message reste rattaché
            // techniquement au dirigeant (audit/notifications), mais l'affichage
            // (nom + badge) doit montrer la gare — voir toDto().
            author = partnerService.getCurrentPartnerForOperations().getOwner();
            postingStation = sp.getStation();
        } else {
            author = userService.findById(userIdOf(principal));
        }

        TripChannelMessage m = new TripChannelMessage();
        m.setTrip(trip);
        m.setAuthor(author);
        m.setStation(postingStation);
        m.setBody(body);
        TripChannelMessage saved = messageRepository.save(m);
        inboxNotificationService.fanOutChannelMessage(trip, saved);
        return toDto(saved);
    }

    @Transactional(readOnly = true)
    public List<TripChannelMessageResponseDTO> listMessages(Long tripId, Object principal) {
        assertCanView(tripId, principal);
        return messageRepository.findByTripIdOrderByCreatedAtAsc(tripId).stream()
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    private void assertCanView(Long tripId, Object p) {
        Trip trip = tripRepository.findByIdWithPartnerAndStops(tripId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
        if (isAdmin(p)) {
            return;
        }
        if (isPartnerForTrip(trip, p) || isGareForTrip(trip, p)) {
            return;
        }
        Long userId = userIdOf(p);
        if (userId != null && ticketRepository.existsActiveTicketForTripAndPassenger(tripId, userId)) {
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Vous n'avez pas accès à ce fil de messages.");
    }

    private void assertCanPost(Trip trip, Object p) {
        if (isAdmin(p)) {
            return;
        }
        if (isPartnerForTrip(trip, p) || isGareForTrip(trip, p)) {
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                "Seuls le partenaire, la gare concernée ou un administrateur peuvent publier ici.");
    }

    private boolean isAdmin(Object p) {
        if (p instanceof org.springframework.security.core.userdetails.UserDetails ud) {
            return ud.getAuthorities().stream().anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        }
        return false;
    }

    private boolean isPartnerForTrip(Trip trip, Object p) {
        Long partnerId = partnerIdOf(p);
        if (partnerId == null || trip.getPartner() == null) {
            return false;
        }
        return partnerId.equals(trip.getPartner().getId()) && hasRole(p, "ROLE_PARTNER");
    }

    private boolean isGareForTrip(Trip trip, Object p) {
        Long stationId = stationIdOf(p);
        if (stationId == null || trip.getStation() == null) {
            return false;
        }
        return stationId.equals(trip.getStation().getId())
                && (hasRole(p, "ROLE_GARE") || hasRole(p, "ROLE_STATION"));
    }

    private boolean hasRole(Object p, String role) {
        if (p instanceof org.springframework.security.core.userdetails.UserDetails ud) {
            return ud.getAuthorities().stream().map(GrantedAuthority::getAuthority).toList().contains(role);
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

    private static Long partnerIdOf(Object principal) {
        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal sp) {
            return sp.getPartnerId();
        }
        if (principal instanceof UserPrincipal up) {
            return up.getPartnerId();
        }
        return null;
    }

    private static Long userIdOf(Object principal) {
        if (principal instanceof UserPrincipal up) {
            return up.getUser().getId();
        }
        return null;
    }

    private TripChannelMessageResponseDTO toDto(TripChannelMessage m) {
        if (m.getStation() != null) {
            return TripChannelMessageResponseDTO.builder()
                    .id(m.getId())
                    .body(m.getBody())
                    .createdAt(m.getCreatedAt())
                    .authorName("Gare " + m.getStation().getName())
                    .authorRole("STATION")
                    .build();
        }
        User a = m.getAuthor();
        String r = a != null && a.getRoles() != null && !a.getRoles().isEmpty()
                ? a.getRoles().iterator().next().getName().name()
                : "";
        String name;
        if ("PARTNER".equals(r)) {
            name = "La direction";
        } else if ("ADMIN".equals(r)) {
            name = "Support Mobili";
        } else {
            name = a == null ? "?" : (nullTo(a.getFirstname()) + " " + nullTo(a.getLastname())).strip();
            if (name.isEmpty()) {
                name = a.getLogin() != null ? a.getLogin() : "?";
            }
        }
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
