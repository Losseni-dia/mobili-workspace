package com.mobili.backend.api.admin;

import com.mobili.backend.module.claim.dto.ClaimResponse;
import com.mobili.backend.module.claim.dto.UpdateClaimStatusRequest;
import com.mobili.backend.module.claim.enums.ClaimStatus;
import com.mobili.backend.module.claim.service.ClaimService;

import jakarta.validation.Valid;

import lombok.RequiredArgsConstructor;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** Liste et traitement des réclamations — protégé par le filtre global "/admin/**" (ROLE_ADMIN). */
@RestController
@RequestMapping("/admin/claims")
@RequiredArgsConstructor
public class AdminClaimController {

    private final ClaimService claimService;

    @GetMapping
    public ResponseEntity<List<ClaimResponse>> listClaims(
            @RequestParam(required = false) ClaimStatus status) {
        return ResponseEntity.ok(claimService.listClaims(status));
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<ClaimResponse> updateStatus(
            @PathVariable Long id, @Valid @RequestBody UpdateClaimStatusRequest request) {
        return ResponseEntity.ok(claimService.updateStatus(
                id, request.status(), request.adminNote(), request.resolutionMessage()));
    }
}
