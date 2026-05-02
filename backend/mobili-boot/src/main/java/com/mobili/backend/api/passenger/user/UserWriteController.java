package com.mobili.backend.api.passenger.user;

import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

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
@RequestMapping("/v1/users")
@RequiredArgsConstructor
public class UserWriteController {

    private final UserService userService;
    private final UserMapper userMapper; // Injection via constructeur
    private final GareProfileEnricher gareProfileEnricher;
    private final CovoiturageProfileEnricher covoiturageProfileEnricher;

    @PatchMapping("/{id}/toggle-status")
    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    public void toggleStatus(@PathVariable Long id, @RequestParam boolean enabled) {
        userService.toggleUserStatus(id, enabled);
    }

    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAuthority('ROLE_ADMIN') or #id == authentication.principal.user.id")
    public ProfileDTO update(
            @PathVariable Long id,
            @RequestPart("user") @Valid UpdateUserDTO dto, // 💡 Changé ici
            @RequestPart(value = "avatar", required = false) MultipartFile avatar) {

        User updatedInfo = userMapper.toEntity(dto);
        // Le service s'occupera de hasher le password s'il n'est pas blank
        User user = userService.updateUser(id, updatedInfo, null, avatar);

        ProfileDTO profile = userMapper.toProfileDto(user);
        gareProfileEnricher.enrich(profile, user);
        covoiturageProfileEnricher.enrich(profile, user);
        return profile;
    }
}