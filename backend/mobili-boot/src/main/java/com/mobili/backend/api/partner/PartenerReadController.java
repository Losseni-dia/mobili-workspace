package com.mobili.backend.api.partner;

import lombok.RequiredArgsConstructor;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partner.dto.PartnerProfileDTO;
import com.mobili.backend.module.partner.dto.mapper.PartnerMapper;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/v1/partners")
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

    @GetMapping("/my-company")
    @PreAuthorize("hasAnyRole('PARTNER', 'GARE', 'ADMIN')")
    public PartnerProfileDTO getMyCompany(@AuthenticationPrincipal UserPrincipal principal) {

        if (principal == null || principal.getUser() == null) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Utilisateur non identifié");
        }

        return partenaireMapper.toProfileDto(
                partenaireService.getCurrentPartnerEnsuringRegistrationCode());
    }
}