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
import com.mobili.backend.module.station.dto.GareUserAffiliationRequest;
import com.mobili.backend.module.station.dto.GareUserCreateRequest;
import com.mobili.backend.module.station.dto.GareUserListItem;
import com.mobili.backend.module.station.dto.GareUserUpdateRequest;
import com.mobili.backend.module.station.dto.StationChauffeurSummary;
import com.mobili.backend.module.station.dto.StationRequestDTO;
import com.mobili.backend.module.station.dto.StationResponseDTO;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.Role;
import com.mobili.backend.module.user.role.RoleRepository;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

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


    public boolean isStationOperational(Station s) {
        return s != null && s.isActive();
    }

    /**
     * Pour la publication de trajets : gare approuvée et active.
     */
    public void assertStationOperationalForTripUse(Station station) {
        if (!isStationOperational(station)) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Cette gare est désactivée. Réactivez-la pour publier des trajets.");
        }
    }

    /**
     * Valeurs par défaut à la création (partenaire ou auto-inscription gare).
     */
    public void applyNewStationDefaults(Station station, Partner partner) {
        station.setPartner(partner);
        station.setCode(generateUniqueStationCode(partner.getId()));
        station.setActive(true);
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
        if (dto.getPassword() == null || dto.getPassword().isBlank()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Le mot de passe de la gare est obligatoire.",
                    Map.of("password", "Le mot de passe de la gare est obligatoire."));
        }
        if (dto.getPassword().trim().length() < 6) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Le mot de passe doit contenir au moins 6 caractères.",
                    Map.of("password", "Le mot de passe doit contenir au moins 6 caractères."));
        }
        Partner partner = partnerService.getCurrentPartnerForOperations();
        Station s = new Station();
        s.setName(dto.getName().trim());
        s.setCity(dto.getCity().trim());
        s.setPassword(passwordEncoder.encode(dto.getPassword().trim()));
        applyNewStationDefaults(s, partner);
        s = stationRepository.saveAndFlush(s);
        Station reloaded = stationRepository.findById(s.getId()).orElse(s);
        if (reloaded.getCode() == null || reloaded.getCode().isBlank()) {
            applyNewStationDefaults(reloaded, partner);
            reloaded = stationRepository.saveAndFlush(reloaded);
        }
        return toDto(reloaded);
    }

    @Transactional
    public StationResponseDTO update(Long id, StationRequestDTO dto, UserPrincipal principal) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        Station s = stationRepository.findByIdAndPartnerId(id, partner.getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Gare introuvable"));
        s.setName(dto.getName().trim());
        s.setCity(dto.getCity().trim());
        if (dto.getActive() != null) {
            s.setActive(dto.getActive());
        }
        if (dto.getPassword() != null && !dto.getPassword().isBlank()) {
            if (dto.getPassword().trim().length() < 6) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                        "Le mot de passe doit contenir au moins 6 caractères.",
                        Map.of("password", "Le mot de passe doit contenir au moins 6 caractères."));
            }
            s.setPassword(passwordEncoder.encode(dto.getPassword().trim()));
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

        if (userRepository.existsByEmailIgnoreCase(dto.getEmail())) {
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
        if (dto.getPhone() != null && !dto.getPhone().isBlank()) {
            u.setPhone(dto.getPhone().trim());
        }
        u.setPassword(passwordEncoder.encode(dto.getPassword()));
        u.setEnabled(isStationOperational(st));
        u.setStation(st);
        u.setBalance(0.0);
        Role gare = roleRepository.findByName(UserRole.GARE)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Rôle GARE manquant (bootstrap)"));
        u.setRoles(Set.of(gare));
        userRepository.save(u);
    }

    @Transactional(readOnly = true)
    public List<GareUserListItem> listGareUsers(UserPrincipal principal) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        return userRepository.findGareUsersByPartnerId(partner.getId()).stream()
                .map(this::toGareUserItem)
                .toList();
    }

    @Transactional
    public GareUserListItem updateGareUser(UserPrincipal principal, Long userId, GareUserUpdateRequest dto) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        User u = userRepository.findByIdWithEverything(userId)
                .orElseThrow(
                        () -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Chef de gare introuvable."));
        validateGareBelongsToPartner(u, partner);
        u.setFirstname(dto.firstname().trim());
        u.setLastname(dto.lastname().trim());
        if (dto.email() != null && !dto.email().isBlank()) {
            String newEmail = dto.email().trim().toLowerCase();
            if (!newEmail.equalsIgnoreCase(u.getEmail()) && userRepository.existsByEmailIgnoreCase(newEmail)) {
                throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Cet email est déjà utilisé.");
            }
            u.setEmail(newEmail);
        }
        if (dto.phone() != null && !dto.phone().isBlank()) {
            u.setPhone(dto.phone().trim());
        }
        if (dto.password() != null && !dto.password().isBlank()) {
            u.setPassword(passwordEncoder.encode(dto.password()));
        }
        return toGareUserItem(userRepository.save(u));
    }

    @Transactional
    public GareUserListItem updateGareUserAffiliation(UserPrincipal principal, Long userId,
            GareUserAffiliationRequest body) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        User u = userRepository.findByIdWithEverything(userId)
                .orElseThrow(
                        () -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Chef de gare introuvable."));
        validateGareBelongsToPartner(u, partner);
        Station s = stationRepository.findByIdAndPartnerId(body.stationId(), partner.getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Gare introuvable."));
        u.setStation(s);
        u.setEnabled(isStationOperational(s));
        userRepository.save(u);
        return toGareUserItem(userRepository.findByIdWithEverything(userId).orElseThrow());
    }

    @Transactional
    public GareUserListItem reactivateGareUser(UserPrincipal principal, Long userId) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        User u = userRepository.findByIdWithEverything(userId)
                .orElseThrow(
                        () -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Chef de gare introuvable."));
        validateGareBelongsToPartner(u, partner);
        u.setEnabled(true);
        return toGareUserItem(userRepository.save(u));
    }

    @Transactional
    public void archiveGareUser(UserPrincipal principal, Long userId) {
        requirePartnerOwner(principal);
        Partner partner = partnerService.getCurrentPartnerForOperations();
        User u = userRepository.findByIdWithEverything(userId)
                .orElseThrow(
                        () -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Chef de gare introuvable."));
        validateGareBelongsToPartner(u, partner);
        u.setEnabled(false);
        userRepository.save(u);
    }

    private void validateGareBelongsToPartner(User u, Partner partner) {
        if (u.getRoles().stream().noneMatch(r -> r.getName() == UserRole.GARE)) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Ce compte n'est pas un chef de gare.");
        }
        if (u.getStation() == null || u.getStation().getPartner() == null
                || !u.getStation().getPartner().getId().equals(partner.getId())) {
            throw new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND,
                    "Chef de gare introuvable pour cette compagnie.");
        }
    }

    private GareUserListItem toGareUserItem(User u) {
        Station s = u.getStation();
        return new GareUserListItem(
                u.getId(),
                u.getFirstname(),
                u.getLastname(),
                u.getEmail(),
                u.getPhone(),
                u.getLogin(),
                u.isEnabled(),
                s != null ? s.getId() : null,
                s != null ? s.getName() : null);
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
        Map<Long, List<User>> grouped = users.stream()
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
                .responsibleName(responsible)
                .assignedChauffeurs(assignedChauffeurs)
                .build();
    }
}