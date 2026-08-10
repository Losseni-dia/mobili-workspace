package com.mobili.backend.module.claim.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.claim.dto.BookingSummaryResponse;
import com.mobili.backend.module.claim.dto.ClaimResponse;
import com.mobili.backend.module.claim.dto.CreateClaimRequest;
import com.mobili.backend.module.claim.dto.PassengerClaimResponse;
import com.mobili.backend.module.claim.entity.Claim;
import com.mobili.backend.module.claim.enums.ClaimStatus;
import com.mobili.backend.module.claim.repository.ClaimRepository;
import com.mobili.backend.module.notification.entity.MobiliNotificationType;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Map;

@Service
@Slf4j
@RequiredArgsConstructor
public class ClaimService {

    // Pas d'ObjectMapper injecté (Spring n'expose pas de bean ObjectMapper dans ce projet —
    // voir AdminService.JSON, même pattern instance statique locale).
    private static final ObjectMapper JSON = new ObjectMapper();

    private final ClaimRepository claimRepository;
    private final UserService userService;
    // BookingService (module booking) injectée directement : aucun cycle de beans possible
    // ici (contrairement au cas FedaPayPaymentService/BookingService vu la veille) — le
    // module claim est neuf, rien dans booking ne dépend de claim.
    private final BookingService bookingService;
    // Même mécanisme de notification que PartnerService/UserService (notifyAdmins) et
    // rejectPartner (notifyUser) — rien de nouveau inventé ici, voir InboxNotificationService.
    private final InboxNotificationService inboxNotificationService;

    @Transactional
    public PassengerClaimResponse createClaim(Long userId, CreateClaimRequest request) {
        if (request.reason() == null) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Le motif de la réclamation est obligatoire.");
        }
        if (request.message() == null || request.message().isBlank()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Un message est requis pour décrire la réclamation.");
        }

        // Rejet propre (400, message clair) — pas d'exception non gérée qui remonterait au
        // fallback générique — quand le motif exige une réservation mais qu'aucune n'est fournie.
        Booking booking = null;
        if (request.reason().requiresBooking()) {
            if (request.bookingId() == null) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                        "Une réservation est requise pour le motif " + request.reason() + ".");
            }
            // Réutilise BookingService.findById telle quelle : contrôle de propriété déjà
            // en place (enforceCanAccessBooking), pas de duplication de cette logique ici.
            booking = bookingService.findById(request.bookingId());
        }

        User user = userService.findById(userId);

        Claim claim = new Claim();
        claim.setUser(user);
        claim.setReason(request.reason());
        claim.setStatus(ClaimStatus.RECEIVED);
        claim.setBooking(booking);
        claim.setMessage(request.message().trim());
        claim.setDetailsJson(toJson(request.details()));

        Claim saved = claimRepository.save(claim);
        log.info("📋 Réclamation #{} créée (motif={}, userId={})", saved.getId(), saved.getReason(), user.getId());

        // Notifie tous les comptes admin — même appel que PartnerService/UserService pour
        // "nouvelle soumission à examiner" (PARTNER_SUBMISSION_PENDING), pas de système
        // parallèle. Résumé court, pas le message brut complet (cohérent avec le style des
        // notifications existantes).
        String bookingContext = saved.getBooking() != null
                ? " — réservation " + saved.getBooking().getReference()
                : "";
        inboxNotificationService.notifyAdmins(
                "Nouvelle réclamation",
                saved.getReason() + bookingContext + " — " + fullName(user),
                MobiliNotificationType.CLAIM_SUBMITTED);

        return toPassengerResponse(saved);
    }

    @Transactional(readOnly = true)
    public List<PassengerClaimResponse> listMyClaims(Long userId) {
        return claimRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(this::toPassengerResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ClaimResponse> listClaims(ClaimStatus statusFilter) {
        List<Claim> claims = statusFilter != null
                ? claimRepository.findByStatusOrderByCreatedAtDesc(statusFilter)
                : claimRepository.findAllByOrderByCreatedAtDesc();
        return claims.stream().map(this::toResponse).toList();
    }

    @Transactional
    public ClaimResponse updateStatus(Long claimId, ClaimStatus newStatus, String adminNote, String resolutionMessage) {
        if (newStatus == null) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Le nouveau statut est obligatoire.");
        }
        Claim claim = claimRepository.findById(claimId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Réclamation introuvable : " + claimId));

        claim.setStatus(newStatus);
        if (adminNote != null && !adminNote.isBlank()) {
            claim.setAdminNote(adminNote.trim());
        }

        boolean isClosing = newStatus == ClaimStatus.RESOLVED || newStatus == ClaimStatus.REJECTED;
        if (isClosing) {
            claim.setResolvedAt(LocalDateTime.now());
            if (resolutionMessage != null && !resolutionMessage.isBlank()) {
                claim.setResolutionMessage(resolutionMessage.trim());
            }
        }

        Claim saved = claimRepository.save(claim);
        log.info("📋 Réclamation #{} passée à {}", saved.getId(), newStatus);

        // Notification de clôture uniquement — pas de bruit à chaque changement de statut
        // intermédiaire (ex. RECEIVED → IN_PROGRESS). Même appel que
        // PartnerService.rejectPartner (notifyUser avec le message rédigé par l'admin).
        if (isClosing) {
            String title = newStatus == ClaimStatus.RESOLVED ? "Réclamation traitée ✅" : "Réclamation rejetée";
            String body = saved.getResolutionMessage() != null
                    ? saved.getResolutionMessage()
                    : (newStatus == ClaimStatus.RESOLVED
                            ? "Votre réclamation a été traitée."
                            : "Votre réclamation a été rejetée.");
            inboxNotificationService.notifyUser(saved.getUser(), title, body, MobiliNotificationType.CLAIM_STATUS_UPDATED);
        }

        return toResponse(saved);
    }

    private ClaimResponse toResponse(Claim claim) {
        return new ClaimResponse(
                claim.getId(),
                claim.getReason(),
                claim.getStatus(),
                claim.getBooking() != null ? BookingSummaryResponse.from(claim.getBooking()) : null,
                claim.getMessage(),
                fromJson(claim.getDetailsJson()),
                claim.getAdminNote(),
                claim.getResolutionMessage(),
                claim.getCreatedAt(),
                claim.getResolvedAt());
    }

    private PassengerClaimResponse toPassengerResponse(Claim claim) {
        return new PassengerClaimResponse(
                claim.getId(),
                claim.getReason(),
                claim.getStatus(),
                claim.getBooking() != null ? BookingSummaryResponse.from(claim.getBooking()) : null,
                claim.getMessage(),
                fromJson(claim.getDetailsJson()),
                claim.getResolutionMessage(),
                claim.getCreatedAt(),
                claim.getResolvedAt());
    }

    private String fullName(User u) {
        if (u == null) {
            return "utilisateur";
        }
        String first = u.getFirstname() != null ? u.getFirstname().trim() : "";
        String last = u.getLastname() != null ? u.getLastname().trim() : "";
        String name = (first + " " + last).trim();
        return name.isEmpty() ? "utilisateur #" + u.getId() : name;
    }

    private String toJson(Map<String, String> details) {
        if (details == null || details.isEmpty()) {
            return null;
        }
        try {
            String json = JSON.writeValueAsString(details);
            return json.length() > 2000 ? json.substring(0, 2000) : json;
        } catch (Exception e) {
            log.warn("Échec sérialisation details réclamation : {}", e.getMessage());
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, String> fromJson(String json) {
        if (json == null || json.isBlank()) {
            return Collections.emptyMap();
        }
        try {
            return JSON.readValue(json, Map.class);
        } catch (Exception e) {
            log.warn("Échec désérialisation details réclamation : {}", e.getMessage());
            return Collections.emptyMap();
        }
    }
}
