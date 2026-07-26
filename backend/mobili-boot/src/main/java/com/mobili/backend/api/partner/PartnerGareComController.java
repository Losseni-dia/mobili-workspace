package com.mobili.backend.api.partner;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.module.partnergarecom.dto.CreatePartnerGareComThreadRequestDTO;
import com.mobili.backend.module.partnergarecom.dto.PartnerGareComMessageResponseDTO;
import com.mobili.backend.module.partnergarecom.dto.PartnerGareComThreadResponseDTO;
import com.mobili.backend.module.partnergarecom.dto.PostPartnerGareComMessageRequestDTO;
import com.mobili.backend.module.partnergarecom.service.PartnerGareComService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/partner-gare-com")
@RequiredArgsConstructor
public class PartnerGareComController {

    private final PartnerGareComService service;

    @GetMapping("/threads")
    @PreAuthorize("hasAnyRole('PARTNER','GARE','ADMIN','STATION')")
    public List<PartnerGareComThreadResponseDTO> listThreads(
            org.springframework.security.core.Authentication authentication) {
        return service.listThreads(authentication.getPrincipal());
    }

    @PostMapping("/threads")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('PARTNER','GARE','ADMIN','STATION')")
    public PartnerGareComThreadResponseDTO createThread(
            @Valid @RequestBody CreatePartnerGareComThreadRequestDTO body,
            org.springframework.security.core.Authentication authentication) {
        return service.createThread(body, authentication.getPrincipal());
    }

    @GetMapping("/threads/{threadId}/messages")
    @PreAuthorize("hasAnyRole('PARTNER','GARE','ADMIN','STATION')")
    public List<PartnerGareComMessageResponseDTO> listMessages(
            @PathVariable Long threadId,
            org.springframework.security.core.Authentication authentication) {
        return service.listMessages(threadId, authentication.getPrincipal());
    }

    @PostMapping("/threads/{threadId}/messages")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('PARTNER','GARE','ADMIN','STATION')")
    public PartnerGareComMessageResponseDTO postMessage(
            @PathVariable Long threadId,
            @Valid @RequestBody PostPartnerGareComMessageRequestDTO body,
            org.springframework.security.core.Authentication authentication) {
        return service.postMessage(threadId, body, authentication.getPrincipal());
    }

    @DeleteMapping("/threads/{threadId}")
    @PreAuthorize("hasAnyRole('PARTNER','GARE','ADMIN','STATION')")
    public org.springframework.http.ResponseEntity<Void> deleteThread(
            @PathVariable Long threadId,
            @org.springframework.web.bind.annotation.RequestParam(defaultValue = "ME") String mode,
            org.springframework.security.core.Authentication authentication) {
        var deleteMode = "EVERYONE".equalsIgnoreCase(mode)
                ? com.mobili.backend.module.partnergarecom.service.PartnerGareComService.DeleteMode.EVERYONE
                : com.mobili.backend.module.partnergarecom.service.PartnerGareComService.DeleteMode.ME;
        service.deleteThread(threadId, deleteMode, authentication.getPrincipal());
        return org.springframework.http.ResponseEntity.noContent().build();
    }
}
