package com.mobili.backend.module.partnergarecom.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.notification.repository.MobiliInboxNotificationRepository;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.partnergarecom.dto.CreatePartnerGareComThreadRequestDTO;
import com.mobili.backend.module.partnergarecom.dto.PartnerGareComMessageResponseDTO;
import com.mobili.backend.module.partnergarecom.dto.PartnerGareComThreadResponseDTO;
import com.mobili.backend.module.partnergarecom.dto.PostPartnerGareComMessageRequestDTO;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComMessage;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThread;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadHidden;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadScope;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadTarget;
import com.mobili.backend.module.partnergarecom.repository.PartnerGareComMessageRepository;
import com.mobili.backend.module.partnergarecom.repository.PartnerGareComThreadHiddenRepository;
import com.mobili.backend.module.partnergarecom.repository.PartnerGareComThreadRepository;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class PartnerGareComService {

    private final PartnerGareComThreadRepository threadRepository;
    private final PartnerGareComMessageRepository messageRepository;
    private final PartnerService partnerService;
    private final StationRepository stationRepository;
    private final PartnerGareComNotificationHelper notificationHelper;
    private final PartnerGareComThreadHiddenRepository hiddenRepository;
    private final MobiliInboxNotificationRepository inboxNotificationRepository;


@Transactional(readOnly = true)
    public List<PartnerGareComThreadResponseDTO> listThreads(Object principal) {
        partnerService.getCurrentPartnerForOperations();
        Long partnerId = requirePartnerId(principal);
        List<PartnerGareComThread> list;
        Long gareStationId = gareStationIdOf(principal);
        if (gareStationId != null) {
            list = threadRepository.findForGareUser(partnerId, gareStationId);
        } else {
            list = threadRepository.findByPartner_IdOrderByLastActivityAtDesc(partnerId);
        }

        java.util.Set<Long> hiddenThreadIds;
        if (gareStationId != null) {
            hiddenThreadIds = hiddenRepository.findByStationId(gareStationId).stream()
                    .map(h -> h.getThread().getId())
                    .collect(java.util.stream.Collectors.toSet());
        } else if (principal instanceof UserPrincipal up) {
            hiddenThreadIds = hiddenRepository.findByUserId(up.getUser().getId()).stream()
                    .map(h -> h.getThread().getId())
                    .collect(java.util.stream.Collectors.toSet());
        } else {
            hiddenThreadIds = java.util.Set.of();
        }

        return list.stream()
                .filter(t -> !hiddenThreadIds.contains(t.getId()))
                .map(t -> toThreadDto(t, loadStations(t)))
                .toList();
    }

    public enum DeleteMode { ME, EVERYONE }

    @Transactional
    public void deleteThread(Long threadId, DeleteMode mode, Object principal) {
        PartnerGareComThread t = getThreadForUser(threadId, principal);

        if (mode == DeleteMode.EVERYONE) {
            inboxNotificationRepository.deleteAllByPartnerGareComThreadId(t.getId());
            messageRepository.deleteAll(messageRepository.findByThread_IdOrderByCreatedAtAsc(t.getId()));
            threadRepository.delete(t);
            return;
        }

        Long gareStationId = gareStationIdOf(principal);
        PartnerGareComThreadHidden h = new PartnerGareComThreadHidden();
        h.setThread(t);
        h.setHiddenAt(LocalDateTime.now());
        if (gareStationId != null) {
            if (hiddenRepository.existsByThreadIdAndStationId(threadId, gareStationId)) {
                return;
            }
            h.setStation(stationRepository.findById(gareStationId).orElseThrow());
        } else if (principal instanceof UserPrincipal up) {
            Long uid = up.getUser().getId();
            if (hiddenRepository.existsByThreadIdAndUserId(threadId, uid)) {
                return;
            }
            h.setUser(up.getUser());
        } else {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Non authentifié");
        }
        hiddenRepository.save(h);
    }

    @Transactional
    public PartnerGareComThreadResponseDTO createThread(
            CreatePartnerGareComThreadRequestDTO req, Object principal) {
        Long partnerId = requirePartnerId(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        assertCanCreateThread(req, principal);

        String titleTrim = req.getTitle().trim();
        if (threadRepository.existsByPartner_IdAndTitle(partnerId, titleTrim)) {
            throw new MobiliException(
                    MobiliErrorCode.DUPLICATE_RESOURCE,
                    "Un fil de discussion avec ce titre existe déjà. Choisissez un autre titre.");
        }

        LocalDateTime now = LocalDateTime.now();
        PartnerGareComThread t = new PartnerGareComThread();
        t.setPartner(partner);
        t.setScope(req.getScope());
        t.setTitle(titleTrim);
        t.setLastActivityAt(now);
        t.setTargets(new ArrayList<>());
        t = threadRepository.save(t);

        Long gareStationId = gareStationIdOf(principal);
        if (req.getScope() == PartnerGareComThreadScope.TARGETED) {
            if (gareStationId != null) {
                Station own = stationRepository.findByIdAndPartnerId(gareStationId, partnerId)
                        .orElseThrow(() -> new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Gare introuvable"));
                PartnerGareComThreadTarget ownTarget = new PartnerGareComThreadTarget();
                ownTarget.setThread(t);
                ownTarget.setStation(own);
                t.getTargets().add(ownTarget);

                // Gare → autre gare : la gare destinataire devient aussi une cible,
                // pour que la conversation soit visible des deux côtés.
                if (req.getStationIds() != null && !req.getStationIds().isEmpty()) {
                    Long otherId = req.getStationIds().get(0);
                    if (!otherId.equals(gareStationId)) {
                        Station other = stationRepository.findByIdAndPartnerId(otherId, partnerId)
                                .orElseThrow(
                                        () -> new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Gare inconnue"));
                        PartnerGareComThreadTarget otherTarget = new PartnerGareComThreadTarget();
                        otherTarget.setThread(t);
                        otherTarget.setStation(other);
                        t.getTargets().add(otherTarget);
                    }
                }
            } else {
                if (req.getStationIds() == null || req.getStationIds().isEmpty()) {
                    throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Sélectionnez au moins une gare");
                }
                for (Long sid : new HashSet<>(req.getStationIds())) {
                    Station st = stationRepository.findByIdAndPartnerId(sid, partnerId)
                            .orElseThrow(() -> new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Gare inconnue"));
                    PartnerGareComThreadTarget tt = new PartnerGareComThreadTarget();
                    tt.setThread(t);
                    tt.setStation(st);
                    t.getTargets().add(tt);
                }
            }
            threadRepository.save(t);
        }

        PartnerGareComMessage first = new PartnerGareComMessage();
        first.setThread(t);
        applyAuthor(first, principal, partner);
        first.setBody(req.getFirstMessage().trim());
        messageRepository.save(first);

        t.setLastActivityAt(first.getCreatedAt() != null ? first.getCreatedAt() : now);
        threadRepository.save(t);

        notificationHelper.notifyOnNewMessage(t, first, principal);
        return toThreadDto(t, loadStations(t));
    }

    @Transactional(readOnly = true)
    public List<PartnerGareComMessageResponseDTO> listMessages(Long threadId, Object principal) {
        PartnerGareComThread t = getThreadForUser(threadId, principal);
        t.getPartner().getId();
        return messageRepository.findByThread_IdOrderByCreatedAtAsc(t.getId()).stream()
                .map(this::toMessageDto)
                .toList();
    }

    @Transactional
    public PartnerGareComMessageResponseDTO postMessage(
            Long threadId, PostPartnerGareComMessageRequestDTO req, Object principal) {
        PartnerGareComThread t = getThreadForUser(threadId, principal);
        LocalDateTime now = LocalDateTime.now();
        PartnerGareComMessage m = new PartnerGareComMessage();
        m.setThread(t);
        applyAuthor(m, principal, t.getPartner());
        m.setBody(req.getBody().trim());
        m = messageRepository.save(m);
        t.setLastActivityAt(m.getCreatedAt() != null ? m.getCreatedAt() : now);
        threadRepository.save(t);
        notificationHelper.notifyOnNewMessage(t, m, principal);
        return toMessageDto(m);
    }

    /**
     * Une gare n'a pas de compte User : l'auteur technique est le dirigeant, la
     * Station est renseignée pour l'affichage.
     */
    private void applyAuthor(PartnerGareComMessage m, Object principal, Partner partner) {
        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal sp) {
            m.setAuthor(partner.getOwner());
            m.setStation(sp.getStation());
        } else if (principal instanceof UserPrincipal up) {
            m.setAuthor(up.getUser());
        } else {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Non authentifié");
        }
    }

    private void assertCanCreateThread(CreatePartnerGareComThreadRequestDTO req, Object principal) {
        Long gareStationId = gareStationIdOf(principal);
        if (gareStationId != null) {
            if (req.getScope() != PartnerGareComThreadScope.TARGETED) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                        "Compte gare : conversation ciblée uniquement (le partenaire ou une autre gare).");
            }
            // Autorisé : aucune gare précisée (= vers le partenaire), ou exactement
            // une autre gare précisée (= vers cette gare). Cibler plusieurs gares
            // ou soi-même explicitement reste refusé.
            if (req.getStationIds() != null && req.getStationIds().size() > 1) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                        "Vous ne pouvez cibler qu'une seule gare à la fois.");
            }
        } else {
            if (!isPartnerOwner(principal)) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                        "Seul le dirigeant peut ouvrir un canal (toutes les gares).");
            }
            if (req.getScope() == PartnerGareComThreadScope.TARGETED
                    && (req.getStationIds() == null || req.getStationIds().isEmpty())) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Sélectionnez une ou plusieurs gares");
            }
        }
    }

    /**
     * Station de la gare si c'est une connexion gare "seule" (StationPrincipal, ou
     * ancien compte GARE sans PARTNER).
     */
    private Long gareStationIdOf(Object principal) {
        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal sp) {
            return sp.getStationId();
        }
        if (principal instanceof UserPrincipal up) {
            boolean gare = up.getUser().getRoles().stream().anyMatch(r -> r.getName() == UserRole.GARE);
            boolean partner = up.getUser().getRoles().stream().anyMatch(r -> r.getName() == UserRole.PARTNER);
            if (gare && !partner) {
                return up.getStationId();
            }
        }
        return null;
    }

    private boolean isPartnerOwner(Object principal) {
        if (!(principal instanceof UserPrincipal up)) {
            return false;
        }
        Partner cp = partnerService.getCurrentPartner();
        return cp.getOwner() != null && cp.getOwner().getId().equals(up.getUser().getId());
    }

    private PartnerGareComThread getThreadForUser(Long threadId, Object principal) {
        Long partnerId = requirePartnerId(principal);
        PartnerGareComThread t = threadRepository.findById(threadId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Fil introuvable"));
        partnerService.assertPartnerCanOperate(t.getPartner());
        if (!t.getPartner().getId().equals(partnerId)) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Autre compagnie");
        }
        Long gareStationId = gareStationIdOf(principal);
        if (gareStationId != null) {
            if (t.getScope() == PartnerGareComThreadScope.ALL) {
                return t;
            }
            boolean ok = t.getTargets().stream()
                    .anyMatch(x -> x.getStation().getId().equals(gareStationId));
            if (!ok) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Vous n'avez pas accès à ce fil");
            }
        }
        return t;
    }

    private Long requirePartnerId(Object principal) {
        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal sp) {
            if (sp.getPartnerId() == null) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Aucun périmètre compagnie");
            }
            return sp.getPartnerId();
        }
        if (principal instanceof UserPrincipal up) {
            if (up.getPartnerId() == null) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Aucun périmètre compagnie");
            }
            return up.getPartnerId();
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Non authentifié");
    }

    private List<Station> loadStations(PartnerGareComThread t) {
        if (t.getScope() == PartnerGareComThreadScope.ALL) {
            return List.of();
        }
        t.getTargets().forEach(x -> x.getStation().getName());
        return t.getTargets().stream().map(PartnerGareComThreadTarget::getStation).toList();
    }

    private PartnerGareComThreadResponseDTO toThreadDto(PartnerGareComThread t, List<Station> stations) {
        return PartnerGareComThreadResponseDTO.builder()
                .id(t.getId())
                .scope(t.getScope())
                .title(t.getTitle())
                .lastActivityAt(t.getLastActivityAt())
                .stationIds(stations.stream().map(Station::getId).toList())
                .stationLabels(stations.stream()
                        .map(s -> s.getCity() + " — " + s.getName())
                        .toList())
                .build();
    }

    private PartnerGareComMessageResponseDTO toMessageDto(PartnerGareComMessage m) {
        if (m.getStation() != null) {
            return PartnerGareComMessageResponseDTO.builder()
                    .id(m.getId())
                    .body(m.getBody())
                    .createdAt(m.getCreatedAt())
                    .authorId(m.getStation().getId())
                    .authorFirstname("Gare")
                    .authorLastname(m.getStation().getName())
                    .authorLogin(m.getStation().getCode())
                    .build();
        }
        User a = m.getAuthor();
        return PartnerGareComMessageResponseDTO.builder()
                .id(m.getId())
                .body(m.getBody())
                .createdAt(m.getCreatedAt())
                .authorId(a.getId())
                .authorFirstname(a.getFirstname())
                .authorLastname(a.getLastname())
                .authorLogin(a.getLogin())
                .build();
    }
}
