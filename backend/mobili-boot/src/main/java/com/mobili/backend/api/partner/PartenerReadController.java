package com.mobili.backend.api.partner;

import lombok.RequiredArgsConstructor;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import com.mobili.backend.module.partner.dto.PartnerProfileDTO;
import com.mobili.backend.module.partner.dto.mapper.PartnerMapper;
import com.mobili.backend.module.partner.service.PartnerService;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/partners")
@RequiredArgsConstructor
public class PartenerReadController {

    private final PartnerService partenaireService;
    private final PartnerMapper partenaireMapper;

    @GetMapping
    public List<PartnerProfileDTO> getAll() {
        return partenaireService.findAll().stream()
                .map(partenaireMapper::toProfileDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    public PartnerProfileDTO getById(@PathVariable Long id) {
        return partenaireMapper.toProfileDto(partenaireService.findById(id));
    }

    /**
     * Pas de {@code @AuthenticationPrincipal UserPrincipal} ici : une connexion gare
     * s'authentifie via {@code StationPrincipal}, pas {@code UserPrincipal} — l'exiger en
     * paramètre le laissait `null` pour ce cas (Spring ne fait pas correspondre le type), d'où un
     * 403 "Utilisateur non identifié" systématique pour toute gare appelant cet endpoint (constaté
     * en test : add-trip côté gare ne pouvait jamais charger le pays de la société, donc jamais de
     * suggestions de ville). PartnerService.getCurrentPartner() lit déjà l'authentification
     * lui-même et gère nativement les deux types de principal — on s'appuie dessus.
     */
    @GetMapping("/my-company")
    @PreAuthorize("hasAnyRole('PARTNER', 'GARE', 'ADMIN','STATION')")
    public PartnerProfileDTO getMyCompany() {
        return partenaireMapper.toProfileDto(
                partenaireService.getCurrentPartnerEnsuringRegistrationCode());
    }
}