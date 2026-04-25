package com.mobili.backend.module.partnergarecom.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partnergarecom.dto.CreatePartnerGareComThreadRequestDTO;
import com.mobili.backend.module.partnergarecom.dto.PartnerGareComMessageResponseDTO;
import com.mobili.backend.module.partnergarecom.dto.PartnerGareComThreadResponseDTO;
import com.mobili.backend.module.partnergarecom.dto.PostPartnerGareComMessageRequestDTO;
import com.mobili.backend.module.partnergarecom.service.PartnerGareComService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/v1/partner-gare-com")
@RequiredArgsConstructor
public class PartnerGareComController {

    private final PartnerGareComService service;

    @GetMapping("/threads")
    @PreAuthorize("hasAnyRole('PARTNER','GARE','ADMIN')")
    public List<PartnerGareComThreadResponseDTO> listThreads(@AuthenticationPrincipal UserPrincipal principal) {
        return service.listThreads(principal);
    }

    @PostMapping("/threads")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('PARTNER','GARE','ADMIN')")
    public PartnerGareComThreadResponseDTO createThread(
            @Valid @RequestBody CreatePartnerGareComThreadRequestDTO body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return service.createThread(body, principal);
    }

    @GetMapping("/threads/{threadId}/messages")
    @PreAuthorize("hasAnyRole('PARTNER','GARE','ADMIN')")
    public List<PartnerGareComMessageResponseDTO> listMessages(
            @PathVariable Long threadId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return service.listMessages(threadId, principal);
    }

    @PostMapping("/threads/{threadId}/messages")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('PARTNER','GARE','ADMIN')")
    public PartnerGareComMessageResponseDTO postMessage(
            @PathVariable Long threadId,
            @Valid @RequestBody PostPartnerGareComMessageRequestDTO body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return service.postMessage(threadId, body, principal);
    }
}
