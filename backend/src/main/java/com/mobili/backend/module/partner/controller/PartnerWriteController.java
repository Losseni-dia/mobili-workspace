package com.mobili.backend.module.partner.controller;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partner.dto.PartnerProfileDTO;
import com.mobili.backend.module.partner.dto.PartnerRegisterDTO;
import com.mobili.backend.module.partner.dto.mapper.PartnerMapper;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.shared.sharedService.UploadService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/v1/partners")
@RequiredArgsConstructor
public class PartnerWriteController {

    private final PartnerService partenaireService;
    private final PartnerMapper partenaireMapper;
    private final UploadService uploadService;

    // INSCRIPTION avec LOGO
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PartnerProfileDTO register(
            @RequestPart("partner") @Valid PartnerRegisterDTO dto,
            @RequestPart(value = "logo", required = false) MultipartFile logoFile,
            @AuthenticationPrincipal UserPrincipal principal) {

        // 1. On transforme le DTO d'inscription en Entité
        Partner entity = partenaireMapper.toEntity(dto);

        // 2. On délègue TOUT au service :
        // - Liaison avec l'Owner (Maya)
        // - Promotion du rôle PARTNER
        // - Upload du logo dans le dossier "partners" (via ta méthode handleLogoUpload)
        Partner savedPartner = partenaireService.save(entity, logoFile, principal);

        return partenaireMapper.toProfileDto(savedPartner);
    }

    // MISE À JOUR DU PROFIL
    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public PartnerProfileDTO update(
            @PathVariable Long id,
            @RequestPart("partner") @Valid PartnerProfileDTO dto,
            @RequestPart(value = "logo", required = false) MultipartFile logoFile,
            @AuthenticationPrincipal UserPrincipal principal) {

        dto.setId(id);
        Partner entity = partenaireMapper.toEntity(dto);

        // On passe l'entité, le fichier et le principal au service
        return partenaireMapper.toProfileDto(partenaireService.save(entity, logoFile, principal));
    }

    @PatchMapping("/{id}/toggle")
    public void toggleStatus(@PathVariable Long id) {
        partenaireService.toggleStatus(id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        partenaireService.delete(id);
    }
}
