package com.mobili.backend.api.partner;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partner.dto.PartnerProfileDTO;
import com.mobili.backend.module.partner.dto.PartnerRegisterDTO;
import com.mobili.backend.module.partner.dto.mapper.PartnerMapper;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/partners")
@RequiredArgsConstructor
public class PartnerWriteController {

    private final PartnerService partenaireService;
    private final PartnerMapper partenaireMapper;

    // INSCRIPTION avec LOGO
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PartnerProfileDTO register(
            @RequestPart("partner") @Valid PartnerRegisterDTO dto,
            @RequestPart(value = "logo", required = false) MultipartFile logoFile,
            @RequestPart(value = "kycFront", required = false) MultipartFile kycFrontFile,
            @RequestPart(value = "kycBack", required = false) MultipartFile kycBackFile,
            @RequestPart(value = "transportCardFront", required = false) MultipartFile transportCardFrontFile,
            @RequestPart(value = "transportCardBack", required = false) MultipartFile transportCardBackFile,
            @AuthenticationPrincipal UserPrincipal principal) {

        Partner entity = partenaireMapper.toEntity(dto);

        Partner savedPartner = partenaireService.save(entity, logoFile, kycFrontFile, kycBackFile,
                transportCardFrontFile, transportCardBackFile, principal);

        return partenaireMapper.toProfileDto(savedPartner);
    }

    // MISE À JOUR DU PROFIL
    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public PartnerProfileDTO update(
            @PathVariable Long id,
            @RequestPart("partner") @Valid PartnerProfileDTO dto,
            @RequestPart(value = "logo", required = false) MultipartFile logoFile,
            @RequestPart(value = "kycFront", required = false) MultipartFile kycFrontFile,
            @RequestPart(value = "kycBack", required = false) MultipartFile kycBackFile,
            @RequestPart(value = "transportCardFront", required = false) MultipartFile transportCardFrontFile,
            @RequestPart(value = "transportCardBack", required = false) MultipartFile transportCardBackFile,
            @AuthenticationPrincipal UserPrincipal principal) {

        dto.setId(id);
        Partner entity = partenaireMapper.toEntity(dto);

        return partenaireMapper.toProfileDto(
                partenaireService.save(entity, logoFile, kycFrontFile, kycBackFile,
                        transportCardFrontFile, transportCardBackFile, principal));
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
