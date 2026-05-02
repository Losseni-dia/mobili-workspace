package com.mobili.backend.module.partnergarecom.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.partnergarecom.dto.CreatePartnerGareComThreadRequestDTO;
import com.mobili.backend.module.partnergarecom.dto.PartnerGareComMessageResponseDTO;
import com.mobili.backend.module.partnergarecom.dto.PartnerGareComThreadResponseDTO;
import com.mobili.backend.module.partnergarecom.dto.PostPartnerGareComMessageRequestDTO;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComMessage;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThread;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadScope;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadTarget;
import com.mobili.backend.module.partnergarecom.repository.PartnerGareComMessageRepository;
import com.mobili.backend.module.partnergarecom.repository.PartnerGareComThreadRepository;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class PartnerGareComService {

    private final PartnerGareComThreadRepository threadRepository;
    private final PartnerGareComMessageRepository messageRepository;
    private final PartnerService partnerService;
    private final StationRepository stationRepository;
    private final PartnerGareComNotificationHelper notificationHelper;

    @Transactional(readOnly = true)
    public List<PartnerGareComThreadResponseDTO> listThreads(UserPrincipal principal) {
        partnerService.getCurrentPartnerForOperations();
        Long partnerId = requirePartnerId(principal);
        List<PartnerGareComThread> list;
        if (isGareOnlyActor(principal)) {
            list = threadRepository.findForGareUser(partnerId, principal.getStationId());
        } else {
            list = threadRepository.findByPartner_IdOrderByLastActivityAtDesc(partnerId);
        }
        return list.stream().map(t -> toThreadDto(t, loadStations(t))).toList();
    }

    @Transactional
    public PartnerGareComThreadResponseDTO createThread(
            CreatePartnerGareComThreadRequestDTO req, UserPrincipal principal) {
        Long partnerId = requirePartnerId(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        assertCanCreateThread(req, principal);

        String titleTrim = req.getTitle().trim();
        if (threadRepository.existsByPartner_IdAndTitle(partnerId, titleTrim)) {
            throw new MobiliException(
                    MobiliErrorCode.DUPLICATE_RESOURCE, "Un fil de discussion avec ce titre existe déjà. Choisissez un autre titre.");
        }

        LocalDateTime now = LocalDateTime.now();
        PartnerGareComThread t = new PartnerGareComThread();
        t.setPartner(partner);
        t.setScope(req.getScope());
        t.setTitle(titleTrim);
        t.setLastActivityAt(now);
        t.setTargets(new ArrayList<>());
        t = threadRepository.save(t);

        if (req.getScope() == PartnerGareComThreadScope.TARGETED) {
            if (isGareOnlyActor(principal)) {
                Long sid = principal.getStationId();
                Station st = stationRepository.findByIdAndPartnerId(sid, partnerId)
                        .orElseThrow(() -> new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Gare introuvable"));
                PartnerGareComThreadTarget tt = new PartnerGareComThreadTarget();
                tt.setThread(t);
                tt.setStation(st);
                t.getTargets().add(tt);
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
        first.setAuthor(principal.getUser());
        first.setBody(req.getFirstMessage().trim());
        messageRepository.save(first);

        t.setLastActivityAt(first.getCreatedAt() != null ? first.getCreatedAt() : now);
        threadRepository.save(t);

        notificationHelper.notifyOnNewMessage(t, first, principal);
        return toThreadDto(t, loadStations(t));
    }

    @Transactional(readOnly = true)
    public List<PartnerGareComMessageResponseDTO> listMessages(Long threadId, UserPrincipal principal) {
        PartnerGareComThread t = getThreadForUser(threadId, principal);
        t.getPartner().getId();
        return messageRepository.findByThread_IdOrderByCreatedAtAsc(t.getId()).stream()
                .map(this::toMessageDto)
                .toList();
    }

    @Transactional
    public PartnerGareComMessageResponseDTO postMessage(
            Long threadId, PostPartnerGareComMessageRequestDTO req, UserPrincipal principal) {
        PartnerGareComThread t = getThreadForUser(threadId, principal);
        LocalDateTime now = LocalDateTime.now();
        PartnerGareComMessage m = new PartnerGareComMessage();
        m.setThread(t);
        m.setAuthor(principal.getUser());
        m.setBody(req.getBody().trim());
        m = messageRepository.save(m);
        t.setLastActivityAt(m.getCreatedAt() != null ? m.getCreatedAt() : now);
        threadRepository.save(t);
        notificationHelper.notifyOnNewMessage(t, m, principal);
        return toMessageDto(m);
    }

    private void assertCanCreateThread(CreatePartnerGareComThreadRequestDTO req, UserPrincipal principal) {
        if (isGareOnlyActor(principal)) {
            if (req.getScope() != PartnerGareComThreadScope.TARGETED) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Compte gare : conversation ciblée uniquement (votre gare).");
            }
            if (req.getStationIds() != null
                    && !req.getStationIds().isEmpty()
                    && (req.getStationIds().size() > 1
                            || !req.getStationIds().get(0).equals(principal.getStationId()))) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Vous ne pouvez cibler que votre gare.");
            }
        } else {
            if (!isPartnerOwner(principal)) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Seul le dirigeant peut ouvrir un canal (toutes les gares).");
            }
            if (req.getScope() == PartnerGareComThreadScope.TARGETED
                    && (req.getStationIds() == null || req.getStationIds().isEmpty())) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Sélectionnez une ou plusieurs gares");
            }
        }
    }

    private boolean isGareOnlyActor(UserPrincipal p) {
        boolean gare = p.getUser().getRoles().stream()
                .anyMatch(r -> r.getName() == UserRole.GARE);
        boolean partner = p.getUser().getRoles().stream()
                .anyMatch(r -> r.getName() == UserRole.PARTNER);
        return gare && !partner;
    }

    private boolean isPartnerOwner(UserPrincipal p) {
        Partner cp = partnerService.getCurrentPartner();
        return cp.getOwner() != null && cp.getOwner().getId().equals(p.getUser().getId());
    }

    private PartnerGareComThread getThreadForUser(Long threadId, UserPrincipal principal) {
        Long partnerId = requirePartnerId(principal);
        PartnerGareComThread t = threadRepository.findById(threadId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Fil introuvable"));
        partnerService.assertPartnerCanOperate(t.getPartner());
        if (!t.getPartner().getId().equals(partnerId)) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Autre compagnie");
        }
        if (isGareOnlyActor(principal)) {
            if (t.getScope() == PartnerGareComThreadScope.ALL) {
                return t;
            }
            boolean ok = t.getTargets().stream()
                    .anyMatch(x -> x.getStation().getId().equals(principal.getStationId()));
            if (!ok) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Vous n'avez pas accès à ce fil");
            }
        }
        return t;
    }

    private Long requirePartnerId(UserPrincipal p) {
        if (p.getPartnerId() == null) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Aucun périmètre compagnie");
        }
        return p.getPartnerId();
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
