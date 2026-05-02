package com.mobili.backend.module.station.service;

import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Collectors;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.station.dto.GareUserCreateRequest;
import com.mobili.backend.module.station.dto.StationChauffeurSummary;
import com.mobili.backend.module.station.dto.StationRequestDTO;
import com.mobili.backend.module.station.dto.StationResponseDTO;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.station.entity.StationApprovalStatus;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.Role;
import com.mobili.backend.module.user.role.RoleRepository;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class StationService {

    private final StationRepository stationRepository;
    private final PartnerService partnerService;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final TripRepository tripRepository;

    /**
     * Statut visuel / métier. Le booléen {@code validated} a priorité s’il est renseigné.
     * Sinon (migration) : déduction à partir d’ {@code approvalStatus} et des codes GAR-…
     */
    public static StationApprovalStatus effectiveApproval(Station s) {
        if (Boolean.FALSE.equals(s.getValidated())) {
            return StationApprovalStatus.PENDING;
        }
        if (Boolean.TRUE.equals(s.getValidated())) {
            return s.isActive() ? StationApprovalStatus.APPROVED : StationApprovalStatus.PENDING;
        }
        if (s.getApprovalStatus() != null) {
            return s.getApprovalStatus();
        }
        String c = s.getCode();
        if (c != null && c.startsWith("GAR-") && !s.isActive()) {
            return StationApprovalStatus.PENDING;
        }
        if (c != null && c.startsWith("GAR-") && s.isActive()) {
            return StationApprovalStatus.APPROVED;
        }
        if (s.isActive()) {
            return StationApprovalStatus.APPROVED;
        }
        return StationApprovalStatus.APPROVED;
    }

    public boolean isStationOperational(Station s) {
        if (s == null) {
            return false;
        }
        if (Boolean.FALSE.equals(s.getValidated())) {
            return false;
        }
        if (Boolean.TRUE.equals(s.getValidated())) {
            return s.isActive();
        }
        return effectiveApproval(s) == StationApprovalStatus.APPROVED && s.isActive();
    }

    /**
     * Pour la publication de trajets : gare approuvée et active.
     */
    public void assertStationOperationalForTripUse(Station station) {
        if (!isStationOperational(station)) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Cette gare n'est pas encore validée pour les trajets. Le dirigeant doit l'approuver.");
        }
    }

    /**
     * Valeurs par défaut à la création (partenaire ou auto-inscription gare).
     */
    public void applyNewStationDefaults(Station station, Partner partner) {
        station.setPartner(partner);
        station.setCode(generateUniqueStationCode(partner.getId()));
        station.setApprovalStatus(StationApprovalStatus.PENDING);
        station.setActive(false);
        station.setValidated(Boolean.FALSE);
    }

    @Transactional(readOnly = true)
    public List<StationResponseDTO> listForCurrentUser(UserPrincipal principal) {
        Partner partner = partnerService.getCurrentPartnerForOperations();
        User u = principal.getUser();
        if (u.getStation() != null) {
            Station s = u.getStation();
            s.getPartner().getId(); // init
            if (!s.getPartner().getId().equals(partner.getId())) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Gare non alignée au partenaire");
            }
            Map<Long, List<StationChauffeurSummary>> aff = loadChauffeursByStationIds(List.of(s.getId()));
            return List.of(toDto(s, aff.getOrDefault(s.getId(), List.of())));
        }
        List<Station> gares = stationRepository.findByPartnerIdOrderByCityAscNameAsc(partner.getId());
        List<Long> ids = gares.stream().map(Station::getId).toList();
        Map<Long, List<StationChauffeurSummary>> aff = loadChauffeursByStationIds(ids);
        return gares.stream()
                .map(st -> toDto(st, aff.getOrDefault(st.getId(), List.of())))
                .toList();
    }

    @Transactional
    public StationResponseDTO create(StationRequestDTO dto, UserPrincipal principal) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        Station s = new Station();
        s.setName(dto.getName().trim());
        s.setCity(dto.getCity().trim());
        applyNewStationDefaults(s, partner);
        s = stationRepository.saveAndFlush(s);
        Station reloaded = stationRepository.findById(s.getId()).orElse(s);
        if (reloaded.getApprovalStatus() == null
                || reloaded.getCode() == null
                || reloaded.getCode().isBlank()) {
            applyNewStationDefaults(reloaded, partner);
            reloaded = stationRepository.saveAndFlush(reloaded);
        }
        return toDto(reloaded);
    }

    @Transactional
    public StationResponseDTO approve(Long id, UserPrincipal principal) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        Station s = stationRepository.findByIdAndPartnerId(id, partner.getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Gare introuvable"));
        if (isStationOperational(s)) {
            if (!Boolean.TRUE.equals(s.getValidated())) {
                s.setValidated(Boolean.TRUE);
                s = stationRepository.save(s);
            }
            return toDto(s);
        }
        s.setApprovalStatus(StationApprovalStatus.APPROVED);
        s.setValidated(Boolean.TRUE);
        s.setActive(true);
        if (s.getCode() == null || s.getCode().isBlank()) {
            s.setCode(generateUniqueStationCode(partner.getId()));
        }
        s = stationRepository.save(s);
        userRepository.enableUsersForStation(s.getId());
        return toDto(s);
    }

    @Transactional
    public StationResponseDTO update(Long id, StationRequestDTO dto, UserPrincipal principal) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        Station s = stationRepository.findByIdAndPartnerId(id, partner.getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Gare introuvable"));
        s.setName(dto.getName().trim());
        s.setCity(dto.getCity().trim());
        if (effectiveApproval(s) == StationApprovalStatus.PENDING) {
            s.setActive(false);
        } else if (dto.getActive() != null) {
            s.setActive(dto.getActive());
        }
        return toDto(stationRepository.save(s));
    }

    @Transactional
    public void delete(Long id, UserPrincipal principal) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        Station s = stationRepository.findByIdAndPartnerId(id, partner.getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Gare introuvable"));
        if (userRepository.findAll().stream()
                .anyMatch(u -> u.getStation() != null && u.getStation().getId().equals(s.getId()))) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Impossible de supprimer : des comptes gare sont encore rattachés");
        }
        if (tripRepository.countTripsByPartnerAndStation(partner.getId(), id) > 0) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Impossible de supprimer : des voyages référencent encore cette gare");
        }
        stationRepository.delete(s);
    }

    @Transactional
    public void createGareUser(GareUserCreateRequest dto, UserPrincipal principal) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        Station st = stationRepository.findByIdAndPartnerId(dto.getStationId(), partner.getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Gare introuvable"));

        if (userRepository.existsByEmail(dto.getEmail())) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Cet email est déjà utilisé.");
        }
        if (userRepository.existsByLogin(dto.getLogin())) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Ce login est déjà utilisé.");
        }
        User u = new User();
        u.setLogin(dto.getLogin().trim());
        u.setEmail(dto.getEmail().trim());
        u.setFirstname(dto.getFirstname().trim());
        u.setLastname(dto.getLastname().trim());
        u.setPassword(passwordEncoder.encode(dto.getPassword()));
        u.setEnabled(isStationOperational(st));
        u.setStation(st);
        u.setBalance(0.0);
        Role gare = roleRepository.findByName(UserRole.GARE)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Rôle GARE manquant (bootstrap)"));
        u.setRoles(Set.of(gare));
        userRepository.save(u);
    }

    public Station getStationForPartnerOrThrow(Long stationId, Long partnerId) {
        return stationRepository.findByIdAndPartnerId(stationId, partnerId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Gare introuvable"));
    }

    private String generateUniqueStationCode(Long partnerId) {
        ThreadLocalRandom rng = ThreadLocalRandom.current();
        for (int attempt = 0; attempt < 40; attempt++) {
            StringBuilder sb = new StringBuilder("GAR-");
            for (int i = 0; i < 5; i++) {
                int c = rng.nextInt(36);
                sb.append(c < 10 ? (char) ('0' + c) : (char) ('A' + c - 10));
            }
            String code = sb.toString();
            if (!stationRepository.existsByPartnerIdAndCode(partnerId, code)) {
                return code;
            }
        }
        throw new MobiliException(MobiliErrorCode.INTERNAL_SERVER_ERROR,
                "Impossible de générer un code gare unique.");
    }

    private void requirePartnerOwner(UserPrincipal principal) {
        partnerService.requirePartnerDirigeant(principal);
    }

    private Map<Long, List<StationChauffeurSummary>> loadChauffeursByStationIds(List<Long> stationIds) {
        Map<Long, List<StationChauffeurSummary>> out = new HashMap<>();
        if (stationIds == null || stationIds.isEmpty()) {
            return out;
        }
        List<User> users = userRepository.findChauffeursByAffiliationStationIds(stationIds);
        Map<Long, List<User>> grouped =
                users.stream()
                        .filter(x -> x.getChauffeurAffiliationStation() != null)
                        .collect(Collectors.groupingBy(x -> x.getChauffeurAffiliationStation().getId()));
        for (Long sid : stationIds) {
            List<StationChauffeurSummary> rows = grouped.getOrDefault(sid, List.of()).stream()
                    .map(
                            u -> new StationChauffeurSummary(
                                    u.getId(), u.getFirstname(), u.getLastname()))
                    .sorted(Comparator
                            .comparing(
                                    (StationChauffeurSummary r) -> nullToEmpty(r.lastname()),
                                    String.CASE_INSENSITIVE_ORDER)
                            .thenComparing(
                                    r -> nullToEmpty(r.firstname()), String.CASE_INSENSITIVE_ORDER)
                            .thenComparing(StationChauffeurSummary::id))
                    .toList();
            out.put(sid, rows);
        }
        return out;
    }

    private static String nullToEmpty(String s) {
        return s == null ? "" : s;
    }

    private StationResponseDTO toDto(Station s) {
        return toDto(s, List.of());
    }

    private StationResponseDTO toDto(Station s, List<StationChauffeurSummary> assignedChauffeurs) {
        StationApprovalStatus appr = effectiveApproval(s);
        String responsible = userRepository.findGareUsersByStationIdOrderByIdAsc(s.getId()).stream()
                .findFirst()
                .map(u -> {
                    String fn = u.getFirstname() != null ? u.getFirstname().trim() : "";
                    String ln = u.getLastname() != null ? u.getLastname().trim() : "";
                    String full = (fn + " " + ln).trim();
                    return full.isEmpty() ? null : full;
                })
                .orElse(null);

        return StationResponseDTO.builder()
                .id(s.getId())
                .name(s.getName())
                .city(s.getCity())
                .code(s.getCode())
                .active(s.isActive())
                .partnerId(s.getPartner() != null ? s.getPartner().getId() : null)
                .approvalStatus(appr.name())
                .validated(resolvedValidatedFlag(s, appr))
                .responsibleName(responsible)
                .assignedChauffeurs(assignedChauffeurs)
                .build();
    }

    /**
     * Libellé API : dès que le booléen persistant est renvoyé, l’UI peut s’y fier ;
     * sinon repli sur le statut d’approbation effectif.
     */
    private static boolean resolvedValidatedFlag(Station s, StationApprovalStatus appr) {
        if (s.getValidated() != null) {
            return s.getValidated();
        }
        return appr == StationApprovalStatus.APPROVED;
    }
}
