package com.mobili.backend.module.notification.controller;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.notification.dto.PostChannelMessageRequestDTO;
import com.mobili.backend.module.notification.dto.TripChannelMessageResponseDTO;
import com.mobili.backend.module.notification.service.TripChannelService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/v1/trips/{tripId}/channel")
@RequiredArgsConstructor
public class TripChannelController {

    private final TripChannelService tripChannelService;

    @GetMapping("/messages")
    public List<TripChannelMessageResponseDTO> list(
            @PathVariable Long tripId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return tripChannelService.listMessages(tripId, principal);
    }

    @PostMapping("/messages")
    @ResponseStatus(HttpStatus.CREATED)
    public TripChannelMessageResponseDTO post(
            @PathVariable Long tripId,
            @RequestBody @Valid PostChannelMessageRequestDTO body,
            @AuthenticationPrincipal UserPrincipal principal) {
        return tripChannelService.postMessage(tripId, body, principal);
    }
}
