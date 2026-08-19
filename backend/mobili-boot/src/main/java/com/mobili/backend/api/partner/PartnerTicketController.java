package com.mobili.backend.api.partner;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.module.booking.ticket.dto.PartnerTicketResponse;
import com.mobili.backend.module.booking.ticket.service.PartnerTicketService;
import com.mobili.backend.module.booking.ticket.util.TicketSegmentUtil;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/tickets/partner")
@RequiredArgsConstructor
public class PartnerTicketController {

    private final PartnerTicketService partnerTicketService;

    @GetMapping("/my-tickets/range")
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN', 'ROLE_STATION')")
    public List<PartnerTicketResponse> getMyTicketsInRange(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate,
            @RequestParam(required = false) Long stationId,
            @RequestParam(required = false) String search) {
        return partnerTicketService.findMyTicketsInRange(fromDate, toDate, stationId, search).stream()
                .map(t -> new PartnerTicketResponse(
                        t.getId(),
                        t.getTicketNumber(),
                        t.getPassengerName(),
                        TicketSegmentUtil.resolveRouteLabel(t),
                        t.getTrip().getStation() != null ? t.getTrip().getStation().getName() : "—",
                        t.getBookingDate(),
                        t.getAmountPaid(),
                        // Vente brute côté compagnie — jamais amountPaid, qui dilue le forfait
                        // client sur chaque siège. Null (ticket antérieur) -> le front retombe
                        // sur amountPaid.
                        t.getTransportFare() != null
                                ? t.getTransportFare() + (t.getBaggageFee() != null ? t.getBaggageFee() : 0.0)
                                : null,
                        t.getStatus() != null ? t.getStatus().name() : "—",
                        t.getSeatNumber(),
                        t.isScanned()))
                .collect(Collectors.toList());
    }
}