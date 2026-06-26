package com.mobili.backend.api.partner;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.station.dto.GareUserAffiliationRequest;
import com.mobili.backend.module.station.dto.GareUserListItem;
import com.mobili.backend.module.station.dto.GareUserUpdateRequest;
import com.mobili.backend.module.station.service.StationService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/partenaire/gare-users")
@RequiredArgsConstructor
@PreAuthorize("hasAuthority('ROLE_PARTNER')")
public class GareUserController {

    private final StationService stationService;

    @GetMapping
    public List<GareUserListItem> list(@AuthenticationPrincipal UserPrincipal principal) {
        return stationService.listGareUsers(principal);
    }

    @PutMapping("/{id}")
    public GareUserListItem update(
            @PathVariable Long id,
            @Valid @RequestBody GareUserUpdateRequest body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return stationService.updateGareUser(principal, id, body);
    }

    @PatchMapping("/{id}/affiliation")
    public GareUserListItem updateAffiliation(
            @PathVariable Long id,
            @Valid @RequestBody GareUserAffiliationRequest body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return stationService.updateGareUserAffiliation(principal, id, body);
    }

    @PatchMapping("/{id}/reactivate")
    public GareUserListItem reactivate(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal principal) {
        return stationService.reactivateGareUser(principal, id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void archive(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal principal) {
        stationService.archiveGareUser(principal, id);
    }
}
