package com.mobili.backend.module.partner.service;

import java.util.Comparator;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partner.dto.PartnerChauffeurAffiliationRequest;
import com.mobili.backend.module.partner.dto.PartnerChauffeurCreateRequest;
import com.mobili.backend.module.partner.dto.PartnerChauffeurListItem;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class PartnerChauffeurService {

    private final UserRepository userRepository;
    private final PartnerService partnerService;
    private final UserService userService;
    private final StationRepository stationRepository;

    @Transactional
    public PartnerChauffeurListItem registerCompanyChauffeur(
            UserPrincipal principal, PartnerChauffeurCreateRequest dto) {
        partnerService.requireDirigeantOuGareDeLaCompagnie(principal);
        Partner comp = partnerService.getCurrentPartnerForOperations();
        return toItem(userService.registerCompanyChauffeur(comp, dto));
    }

    @Transactional
    public PartnerChauffeurListItem updateChauffeurAffiliation(
            UserPrincipal principal, Long chauffeurUserId, PartnerChauffeurAffiliationRequest body) {
        partnerService.requireDirigeantOuGareDeLaCompagnie(principal);
        Partner comp = partnerService.getCurrentPartnerForOperations();
        User u = userRepository
                .findByIdWithEverything(chauffeurUserId)
                .orElseThrow(() -> new MobiliException(
                        MobiliErrorCode.RESOURCE_NOT_FOUND, "Utilisateur introuvable."));
        if (u.getEmployerPartner() == null || !u.getEmployerPartner().getId().equals(comp.getId())) {
            throw new MobiliException(
                    MobiliErrorCode.RESOURCE_NOT_FOUND, "Chauffeur introuvable pour cette compagnie.");
        }
        if (u.getRoles().stream().noneMatch(r -> r.getName() == UserRole.CHAUFFEUR)) {
            throw new MobiliException(
                    MobiliErrorCode.VALIDATION_ERROR, "Ce compte n'est pas un chauffeur de votre compagnie.");
        }
        if (body.stationId() == null) {
            u.setChauffeurAffiliationStation(null);
        } else {
            Station s = stationRepository
                    .findByIdAndPartnerId(body.stationId(), comp.getId())
                    .orElseThrow(() -> new MobiliException(
                            MobiliErrorCode.RESOURCE_NOT_FOUND,
                            "Gare inconnue ou ne dépend pas de cette compagnie."));
            u.setChauffeurAffiliationStation(s);
        }
        userRepository.save(u);
        return toItem(userRepository
                .findByIdWithEverything(chauffeurUserId)
                .orElseThrow());
    }

    @Transactional(readOnly = true)
    public List<PartnerChauffeurListItem> listForCurrentPartner() {
        Partner p = partnerService.getCurrentPartnerForOperations();
        return userRepository.findChauffeursByEmployerPartnerId(p.getId()).stream()
                .sorted(Comparator
                        .comparing((User u) -> nullToEmpty(u.getLastname()), String.CASE_INSENSITIVE_ORDER)
                        .thenComparing((User u) -> nullToEmpty(u.getFirstname()), String.CASE_INSENSITIVE_ORDER)
                        .thenComparingLong(User::getId))
                .map(this::toItem)
                .toList();
    }

    private static String nullToEmpty(String s) {
        return s == null ? "" : s;
    }

    private PartnerChauffeurListItem toItem(User u) {
        var aff = u.getChauffeurAffiliationStation();
        return new PartnerChauffeurListItem(
                u.getId(),
                u.getFirstname(),
                u.getLastname(),
                u.getEmail(),
                u.isEnabled(),
                aff != null ? aff.getId() : null,
                aff != null ? aff.getName() : null);
    }
}
