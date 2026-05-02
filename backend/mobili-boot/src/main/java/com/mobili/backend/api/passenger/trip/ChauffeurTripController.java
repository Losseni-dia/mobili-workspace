package com.mobili.backend.api.passenger.trip;

import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.trip.dto.chauffeur.ChauffeurTripsOverviewResponse;
import com.mobili.backend.module.trip.service.TripService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping(value = "/v1/trips/chauffeur", produces = MediaType.APPLICATION_JSON_VALUE)
@RequiredArgsConstructor
public class ChauffeurTripController {

    private final TripService tripService;

    @GetMapping("/mine")
    @PreAuthorize("hasAnyRole('CHAUFFEUR', 'ADMIN')")
    public ChauffeurTripsOverviewResponse mine(@AuthenticationPrincipal UserPrincipal principal) {
        return tripService.getChauffeurTripsOverview(principal);
    }
}
