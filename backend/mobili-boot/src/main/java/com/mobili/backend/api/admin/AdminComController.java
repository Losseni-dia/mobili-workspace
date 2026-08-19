package com.mobili.backend.api.admin;

import com.mobili.backend.module.admincom.dto.*;
import com.mobili.backend.module.admincom.service.AdminComService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

/**
 * {@code principal} typé {@code Authentication} (pas {@code @AuthenticationPrincipal
 * UserPrincipal}) : une session gare s'authentifie comme {@code StationPrincipal}, pas comme
 * {@code UserPrincipal} — l'ancienne signature liait silencieusement {@code null} pour ces
 * sessions (types incompatibles, {@code errorOnInvalidType=false} par défaut côté Spring
 * Security) et {@code AdminComService} NPEait derrière. Voir {@code AdminComService.resolveCallerUser}
 * pour la résolution gare → dirigeant.
 */
@RestController
@RequestMapping("/admin-com")
@RequiredArgsConstructor
public class AdminComController {

    private final AdminComService adminComService;

    @PostMapping("/threads")
    public ResponseEntity<AdminComThreadDTO> createThread(
            @Valid @RequestBody CreateAdminComThreadRequest req,
            Authentication authentication) {
        return ResponseEntity.ok(adminComService.createThread(req, authentication.getPrincipal()));
    }

    @GetMapping("/threads")
    public ResponseEntity<List<AdminComThreadDTO>> listThreads(Authentication authentication) {
        return ResponseEntity.ok(adminComService.listThreads(authentication.getPrincipal()));
    }

    @GetMapping("/threads/{threadId}/messages")
    public ResponseEntity<List<AdminComMessageDTO>> listMessages(
            @PathVariable Long threadId,
            Authentication authentication) {
        return ResponseEntity.ok(adminComService.listMessages(threadId, authentication.getPrincipal()));
    }

    @PostMapping("/threads/{threadId}/messages")
    public ResponseEntity<AdminComMessageDTO> postMessage(
            @PathVariable Long threadId,
            @Valid @RequestBody PostAdminComMessageRequest req,
            Authentication authentication) {
        return ResponseEntity.ok(adminComService.postMessage(threadId, req, authentication.getPrincipal()));
    }

    // Message avec preuve jointe (image/PDF) — texte optionnel (multipart/form-data au lieu
    // du JSON habituel, un fichier ne peut pas voyager dans un @RequestBody JSON classique).
    @PostMapping(value = "/threads/{threadId}/messages/attachment", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<AdminComMessageDTO> postMessageWithAttachment(
            @PathVariable Long threadId,
            @RequestParam(value = "body", required = false) String body,
            @RequestPart("file") MultipartFile file,
            Authentication authentication) {
        return ResponseEntity.ok(
                adminComService.postMessageWithAttachment(threadId, body, file, authentication.getPrincipal()));
    }
}
