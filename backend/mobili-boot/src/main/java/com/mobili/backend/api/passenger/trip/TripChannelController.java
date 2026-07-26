package com.mobili.backend.api.passenger.trip;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.module.notification.dto.PostChannelMessageRequestDTO;
import com.mobili.backend.module.notification.dto.TripChannelMessageResponseDTO;
import com.mobili.backend.module.notification.service.TripChannelService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/trips/{tripId}/channel")
@RequiredArgsConstructor
public class TripChannelController {

    private final TripChannelService tripChannelService;

    @GetMapping("/messages")
    public List<TripChannelMessageResponseDTO> list(
            @PathVariable Long tripId,
            org.springframework.security.core.Authentication authentication) {
        return tripChannelService.listMessages(tripId, authentication.getPrincipal());
    }

    @PostMapping("/messages")
    @ResponseStatus(HttpStatus.CREATED)
    public TripChannelMessageResponseDTO post(
            @PathVariable Long tripId,
            @RequestBody @Valid PostChannelMessageRequestDTO body,
            org.springframework.security.core.Authentication authentication) {
        return tripChannelService.postMessage(tripId, body, authentication.getPrincipal());
    }
}
