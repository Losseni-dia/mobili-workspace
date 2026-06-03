package com.mobili.backend.api.passenger.trip;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.user.dto.ProfileDTO;
import com.mobili.backend.module.user.dto.UpdateCovoiturageProfileDTO;
import com.mobili.backend.module.user.dto.mapper.UserMapper;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.CovoiturageProfileEnricher;
import com.mobili.backend.module.user.service.UserService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/covoiturage/profile")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('CHAUFFEUR', 'ADMIN')")
public class CovoiturageProfileController {

    private final UserService userService;
    private final UserMapper userMapper;
    private final CovoiturageProfileEnricher covoiturageProfileEnricher;

    @PutMapping
    public ProfileDTO update(
            @RequestPart("profile") UpdateCovoiturageProfileDTO dto,
            @RequestPart(value = "driverPhoto", required = false) MultipartFile driverPhoto,
            @RequestPart(value = "vehiclePhoto", required = false) MultipartFile vehiclePhoto,
            @AuthenticationPrincipal UserPrincipal principal) {
        User updated = userService.updateCovoiturageProfile(
                principal.getUser().getId(), dto, driverPhoto, vehiclePhoto);
        ProfileDTO profileDTO = userMapper.toProfileDto(updated);
        covoiturageProfileEnricher.enrich(profileDTO, updated);
        return profileDTO;
    }
}
