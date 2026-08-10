package com.mobili.backend.api.passenger.claim;

import com.mobili.backend.module.claim.dto.CreateClaimRequest;
import com.mobili.backend.module.claim.dto.PassengerClaimResponse;
import com.mobili.backend.module.claim.service.ClaimService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;

import lombok.RequiredArgsConstructor;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.security.Principal;
import java.util.List;

/** Réclamations côté passager — création + historique personnel. */
@RestController
@RequestMapping("/claims")
@RequiredArgsConstructor
public class ClaimController {

    private final ClaimService claimService;
    private final UserService userService;

    // userId déduit du principal authentifié (comme BookingController.create), jamais du
    // corps de la requête — on ne fait jamais confiance au client pour dire qui il est.
    @PostMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<PassengerClaimResponse> createClaim(
            @RequestBody CreateClaimRequest request, Principal principal) {
        User user = userService.findByLogin(principal.getName());
        return ResponseEntity.ok(claimService.createClaim(user.getId(), request));
    }

    // Même pattern que BookingController.getByUserId : userId dans le path, mais contrôle
    // de propriété explicite — pas d'IDOR possible (un autre utilisateur ne peut pas lire
    // les réclamations de quelqu'un d'autre juste en changeant l'ID dans l'URL).
    @GetMapping("/mine/{userId}")
    @PreAuthorize("hasAnyAuthority('ROLE_ADMIN') or #userId == authentication.principal.user.id")
    public ResponseEntity<List<PassengerClaimResponse>> myClaims(@PathVariable Long userId) {
        return ResponseEntity.ok(claimService.listMyClaims(userId));
    }
}
