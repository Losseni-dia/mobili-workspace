package com.mobili.backend.api.partner;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.station.dto.GareUserCreateRequest;
import com.mobili.backend.module.station.dto.StationRequestDTO;
import com.mobili.backend.module.station.dto.StationResponseDTO;
import com.mobili.backend.module.station.service.StationService;
import com.mobili.backend.module.user.dto.UserFcmTokenRequest;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/partenaire/stations")
@RequiredArgsConstructor
@PreAuthorize("hasAnyAuthority('ROLE_PARTNER','ROLE_GARE','ROLE_ADMIN','ROLE_STATION')")
public class StationController {

    private final StationService stationService;

    @GetMapping
    public List<StationResponseDTO> list(org.springframework.security.core.Authentication authentication) {
        return stationService.listForCurrentUser(authentication.getPrincipal());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('ROLE_PARTNER')")
    public StationResponseDTO create(
            @Valid @RequestBody StationRequestDTO body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return stationService.create(body, principal);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('ROLE_PARTNER')")
    public StationResponseDTO update(
            @PathVariable Long id,
            @Valid @RequestBody StationRequestDTO body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return stationService.update(id, body, principal);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('ROLE_PARTNER')")
    public void delete(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal principal) {
        stationService.delete(id, principal);
    }

   @PostMapping("/gare-accounts")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('ROLE_PARTNER')")
    public ResponseEntity<Void> createGareUser(
            @Valid @RequestBody GareUserCreateRequest body,
            @AuthenticationPrincipal UserPrincipal principal) {
        stationService.createGareUser(body, principal);
        return ResponseEntity.status(HttpStatus.CREATED).build();
    }

  @PatchMapping("/me/fcm-token")
    @PreAuthorize("hasAuthority('ROLE_STATION')")
    public ResponseEntity<Void> updateFcmToken(
            @RequestBody UserFcmTokenRequest request,
            org.springframework.security.core.Authentication authentication) {
        var sp = (com.mobili.backend.infrastructure.security.authentication.StationPrincipal) authentication
                .getPrincipal();
        stationService.updateFcmToken(sp.getStationId(), request.fcmToken());
        return ResponseEntity.ok().build();
    }

}
