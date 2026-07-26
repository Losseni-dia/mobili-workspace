package com.mobili.backend.api.passenger.user;

import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.user.dto.ProfileDTO;
import com.mobili.backend.module.user.dto.UpdateUserDTO;
import com.mobili.backend.module.user.dto.mapper.UserMapper;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.CovoiturageProfileEnricher;
import com.mobili.backend.module.user.service.GareProfileEnricher;
import com.mobili.backend.module.user.service.UserService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserWriteController {

    private final UserService userService;
    private final UserMapper userMapper; // Injection via constructeur
    private final GareProfileEnricher gareProfileEnricher;
    private final CovoiturageProfileEnricher covoiturageProfileEnricher;
    private final StationRepository stationRepository;
    private final PasswordEncoder passwordEncoder;

    @PatchMapping("/{id}/toggle-status")
    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    public void toggleStatus(@PathVariable Long id, @RequestParam boolean enabled) {
        userService.toggleUserStatus(id, enabled);
    }

    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("isAuthenticated()")
    public ProfileDTO update(
            @PathVariable Long id,
            @RequestPart("user") @Valid UpdateUserDTO dto,
            @RequestPart(value = "avatar", required = false) MultipartFile avatar,
            org.springframework.security.core.Authentication authentication) {

        Object rawPrincipal = authentication.getPrincipal();

        // Connexion "gare" : seul le mot de passe de la gare est modifiable ici
        // (nom/ville restent gérés par le dirigeant via /partenaire/stations).
        if (rawPrincipal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal stationPrincipal) {
            if (!stationPrincipal.getStationId().equals(id)) {
                throw new com.mobili.backend.shared.mobiliError.exception.MobiliException(
                        com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode.ACCESS_DENIED,
                        "Non autorisé");
            }
            var station = stationPrincipal.getStation();
            if (dto.password() != null && !dto.password().isBlank()) {
                station.setPassword(passwordEncoder.encode(dto.password()));
                stationRepository.save(station);
            }
            ProfileDTO profile = new ProfileDTO();
            profile.setId(station.getId());
            profile.setFirstname(station.getName());
            profile.setLastname("");
            profile.setLogin(station.getCode());
            profile.setEnabled(station.isActive());
            profile.setRoles(java.util.List.of("STATION"));
            profile.setStationId(station.getId());
            profile.setStationName(station.getName());
            profile.setGareOperationsEnabled(station.isActive());
            return profile;
        }

        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        if (!isAdmin
                && (!(rawPrincipal instanceof com.mobili.backend.infrastructure.security.authentication.UserPrincipal up)
                        || !up.getUser().getId().equals(id))) {
            throw new com.mobili.backend.shared.mobiliError.exception.MobiliException(
                    com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode.ACCESS_DENIED,
                    "Non autorisé");
        }

        User updatedInfo = userMapper.toEntity(dto);
        User user = userService.updateUser(id, updatedInfo, dto.oldPassword(), null, avatar);

        ProfileDTO profile = userMapper.toProfileDto(user);
        gareProfileEnricher.enrich(profile, user);
        covoiturageProfileEnricher.enrich(profile, user);
        return profile;
    }
}