package com.mobili.backend.api.admin;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.admincom.dto.*;
import com.mobili.backend.module.admincom.service.AdminComService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/admin-com")
@RequiredArgsConstructor
public class AdminComController {

    private final AdminComService adminComService;

    @PostMapping("/threads")
    public ResponseEntity<AdminComThreadDTO> createThread(
            @Valid @RequestBody CreateAdminComThreadRequest req,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(adminComService.createThread(req, principal));
    }

    @GetMapping("/threads")
    public ResponseEntity<List<AdminComThreadDTO>> listThreads(
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(adminComService.listThreads(principal));
    }

    @GetMapping("/threads/{threadId}/messages")
    public ResponseEntity<List<AdminComMessageDTO>> listMessages(
            @PathVariable Long threadId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(adminComService.listMessages(threadId, principal));
    }

    @PostMapping("/threads/{threadId}/messages")
    public ResponseEntity<AdminComMessageDTO> postMessage(
            @PathVariable Long threadId,
            @Valid @RequestBody PostAdminComMessageRequest req,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(adminComService.postMessage(threadId, req, principal));
    }

    // Message avec preuve jointe (image/PDF) — texte optionnel (multipart/form-data au lieu
    // du JSON habituel, un fichier ne peut pas voyager dans un @RequestBody JSON classique).
    @PostMapping(value = "/threads/{threadId}/messages/attachment", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<AdminComMessageDTO> postMessageWithAttachment(
            @PathVariable Long threadId,
            @RequestParam(value = "body", required = false) String body,
            @RequestPart("file") MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(adminComService.postMessageWithAttachment(threadId, body, file, principal));
    }
}