package com.mobili.backend.module.trip.controller;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.module.booking.ticket.dto.TicketResponseDTO;
import com.mobili.backend.module.booking.ticket.dto.mapper.TicketMapper;
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.service.TicketService;
import com.mobili.backend.module.trip.dto.driver.DriverLuggageSummaryResponse;
import com.mobili.backend.module.trip.dto.driver.AlightingPassengerResponse;
import com.mobili.backend.module.trip.dto.driver.DriverAlightedRequest;
import com.mobili.backend.module.trip.dto.driver.DriverDepartureRequest;
import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/v1/trips/{tripId}/driver")
@RequiredArgsConstructor
@PreAuthorize("hasAnyAuthority('ROLE_CHAUFFEUR', 'ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN')")
public class TripDriverController {

    private final TripService tripService;
    private final TripRunService tripRunService;
    private final TicketService ticketService;
    private final TicketMapper ticketMapper;

    @PostMapping("/departures")
    public void recordDeparture(
            @PathVariable Long tripId,
            @Valid @RequestBody DriverDepartureRequest body,
            @AuthenticationPrincipal UserPrincipal principal) {
        tripService.assertPartnerOrGareCanOperateDriverTrip(tripId, principal);
        Trip trip = tripService.findById(tripId);
        tripRunService.recordDepartureFromStop(trip, body.getStopIndex(), LocalDateTime.now());
    }

    /** Demarrage du service (premier depart enregistre, statut EN_COURS). */
    @PostMapping("/start")
    public void startTrip(
            @PathVariable Long tripId, @AuthenticationPrincipal UserPrincipal principal) {
        tripService.startChauffeurTrip(tripId, principal);
    }

    /** Synthèse bagages (réservations confirmées vs politique du voyage). */
    @GetMapping("/luggage-summary")
    public DriverLuggageSummaryResponse luggageSummary(
            @PathVariable Long tripId, @AuthenticationPrincipal UserPrincipal principal) {
        tripService.assertPartnerOrGareCanOperateDriverTrip(tripId, principal);
        return tripService.getDriverLuggageSummary(tripId);
    }

    @GetMapping("/stops/{stopIndex}/alightings")
    public List<AlightingPassengerResponse> listAlightings(
            @PathVariable Long tripId,
            @PathVariable int stopIndex,
            @AuthenticationPrincipal UserPrincipal principal) {
        tripService.assertPartnerOrGareCanOperateDriverTrip(tripId, principal);
        Trip trip = tripService.findById(tripId);
        return tripRunService.listAlightingPassengers(trip, stopIndex);
    }

    @PostMapping("/tickets/{ticketNumber}/alighted")
    public TicketResponseDTO confirmAlighted(
            @PathVariable Long tripId,
            @PathVariable String ticketNumber,
            @RequestBody(required = false) DriverAlightedRequest body,
            @AuthenticationPrincipal UserPrincipal principal) {
        tripService.assertPartnerOrGareCanOperateDriverTrip(tripId, principal);
        Integer stop = body != null ? body.getStopIndex() : null;
        Ticket ticket = ticketService.confirmPassengerAlightedAtStop(tripId, ticketNumber, stop);
        return ticketMapper.toDto(ticket);
    }
}
