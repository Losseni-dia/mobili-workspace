package com.mobili.backend.api.partner;

import java.util.List;

import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partner.dto.PartnerChauffeurAffiliationRequest;
import com.mobili.backend.module.partner.dto.PartnerChauffeurCreateRequest;
import com.mobili.backend.module.partner.dto.PartnerChauffeurListItem;
import com.mobili.backend.module.partner.service.PartnerChauffeurService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/partenaire/chauffeurs")
@RequiredArgsConstructor
@PreAuthorize("hasAnyAuthority('ROLE_PARTNER','ROLE_GARE','ROLE_ADMIN')")
public class PartnerChauffeurController {

    private final PartnerChauffeurService partnerChauffeurService;

    @GetMapping
    public List<PartnerChauffeurListItem> list() {
        return partnerChauffeurService.listForCurrentPartner();
    }

  @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
public PartnerChauffeurListItem create(
    @RequestPart("chauffeur") @Valid PartnerChauffeurCreateRequest body,
    @RequestPart(value = "avatar", required = false) MultipartFile avatar,
    @AuthenticationPrincipal UserPrincipal principal) {
    return partnerChauffeurService.registerCompanyChauffeur(principal, body, avatar);
}
    @PatchMapping("/{id}/affiliation")
    public PartnerChauffeurListItem updateAffiliation(
            @PathVariable("id") Long userId,
            @RequestBody PartnerChauffeurAffiliationRequest body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return partnerChauffeurService.updateChauffeurAffiliation(principal, userId, body);
    }
}
