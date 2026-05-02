package com.mobili.backend.module.station.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.token.JwtService;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.repository.PartnerRepository;
import com.mobili.backend.module.station.dto.GarePreviewResponse;
import com.mobili.backend.module.station.dto.GareSelfRegisterRequest;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.user.dto.login.AuthResponse;
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
public class GareSelfRegistrationService {

    private final PartnerRepository partnerRepository;
    private final StationRepository stationRepository;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final StationService stationService;

    @Transactional(readOnly = true)
    public GarePreviewResponse preview(String rawCode) {
        String code = normalizeCode(rawCode);
        if (code.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Code compagnie requis");
        }
        Partner p = partnerRepository.findByRegistrationCodeIgnoreCase(code)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Code compagnie inconnu"));
        if (!p.isEnabled()) {
            throw new MobiliException(
                    MobiliErrorCode.ACCESS_DENIED,
                    "Cette compagnie est en attente de validation : les inscriptions gare ne sont pas ouvertes pour l'instant.");
        }
        p.getName();
        return GarePreviewResponse.builder()
                .partnerId(p.getId())
                .partnerName(p.getName())
                .stations(stationRepository.findByPartnerIdOrderByCityAscNameAsc(p.getId()).stream()
                        .filter(stationService::isStationOperational)
                        .map(s -> new GarePreviewResponse.StationOption(s.getId(), s.getName(), s.getCity()))
                        .toList())
                .build();
    }

    @Transactional
    public AuthResponse register(GareSelfRegisterRequest req) {
        String code = normalizeCode(req.getPartnerCode());
        if (code.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Code compagnie requis");
        }
        Partner partner = partnerRepository.findByRegistrationCodeIgnoreCase(code)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Code compagnie inconnu"));
        if (!partner.isEnabled()) {
            throw new MobiliException(
                    MobiliErrorCode.ACCESS_DENIED,
                    "Cette compagnie n'est pas encore validée : l'inscription gare n'est pas disponible.");
        }
        if (userRepository.existsByEmail(req.getEmail().trim())) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Cet email est déjà utilisé.");
        }
        if (userRepository.existsByLogin(req.getLogin().trim())) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Ce login est déjà utilisé.");
        }

        Station station;
        if (req.getStationId() != null) {
            station = stationRepository.findByIdAndPartnerId(req.getStationId(), partner.getId())
                    .orElseThrow(() -> new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Gare inconnue pour ce code"));
            if (!stationService.isStationOperational(station)) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                        "Cette gare n'est pas encore validée. Choisissez une autre gare ou créez une nouvelle demande.");
            }
        } else {
            String n = req.getNewStationName();
            String c = req.getNewStationCity();
            if (n == null || n.isBlank() || c == null || c.isBlank()) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                        "Sélectionnez une gare existante ou saisissez le nom et la ville d’une nouvelle gare");
            }
            station = new Station();
            station.setName(n.trim());
            station.setCity(c.trim());
            stationService.applyNewStationDefaults(station, partner);
            station = stationRepository.save(station);
        }

        User u = new User();
        u.setLogin(req.getLogin().trim());
        u.setEmail(req.getEmail().trim().toLowerCase());
        u.setFirstname(req.getFirstname().trim());
        u.setLastname(req.getLastname().trim());
        u.setPassword(passwordEncoder.encode(req.getPassword()));
        u.setEnabled(stationService.isStationOperational(station));
        u.setStation(station);
        u.setBalance(0.0);
        Role gare = roleRepository.findByName(UserRole.GARE)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Rôle GARE manquant"));
        u.setRoles(java.util.Set.of(gare));
        userRepository.save(u);

        User reloaded = userRepository.findByLogin(u.getLogin())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Utilisateur"));
        String token = reloaded.isEnabled() ? jwtService.generateToken(reloaded) : null;
        Boolean accountPending = reloaded.isEnabled() ? null : Boolean.TRUE;
        return new AuthResponse(token, reloaded.getLogin(), reloaded.getId(), accountPending);
    }

    private static String normalizeCode(String raw) {
        return raw == null ? "" : raw.trim().toUpperCase();
    }
}
