package com.mobili.backend.module.partner.controller;

import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partner.dto.PartnerChauffeurAffiliationRequest;
import com.mobili.backend.module.partner.dto.PartnerChauffeurCreateRequest;
import com.mobili.backend.module.partner.dto.PartnerChauffeurListItem;
import com.mobili.backend.module.partner.service.PartnerChauffeurService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/v1/partenaire/chauffeurs")
@RequiredArgsConstructor
@PreAuthorize("hasAnyAuthority('ROLE_PARTNER','ROLE_GARE','ROLE_ADMIN')")
public class PartnerChauffeurController {

    private final PartnerChauffeurService partnerChauffeurService;

    @GetMapping
    public List<PartnerChauffeurListItem> list() {
        return partnerChauffeurService.listForCurrentPartner();
    }

    @PostMapping
    public PartnerChauffeurListItem create(
            @Valid @RequestBody PartnerChauffeurCreateRequest body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return partnerChauffeurService.registerCompanyChauffeur(principal, body);
    }

    @PatchMapping("/{id}/affiliation")
    public PartnerChauffeurListItem updateAffiliation(
            @PathVariable("id") Long userId,
            @RequestBody PartnerChauffeurAffiliationRequest body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return partnerChauffeurService.updateChauffeurAffiliation(principal, userId, body);
    }
}
