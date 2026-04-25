package com.mobili.backend.module.trip.controller;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.trip.dto.TripResponseDTO;
import com.mobili.backend.module.trip.dto.TripStopResponseDTO;
import com.mobili.backend.module.trip.dto.mapper.TripMapper;
import com.mobili.backend.module.trip.entity.TransportType;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.service.TripService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/v1/trips")
@RequiredArgsConstructor
public class TripReadController {

    private final TripService tripService;
    private final TripMapper tripMapper;
    private final AnalyticsEventService analyticsEventService;

    @GetMapping
    public List<TripResponseDTO> getAll(
            @RequestParam(name = "transportType", required = false) String transportType) {
        TransportType tt = parseTransportType(transportType);
        return tripService.findAllUpcoming(tt).stream()
                .map(tripMapper::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/{id}/stops")
    public List<TripStopResponseDTO> listStops(@PathVariable Long id) {
        return tripService.listStops(id);
    }

    @GetMapping("/{id}")
    public TripResponseDTO getById(@PathVariable Long id) {
        TripResponseDTO dto = tripMapper.toDto(tripService.findById(id));
        dto.setLegFares(tripService.listLegFares(id));
        return dto;
    }

    @GetMapping("/search")
    public List<TripResponseDTO> search(
            @RequestParam(required = false, defaultValue = "") String departure,
            @RequestParam(required = false, defaultValue = "") String arrival,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(name = "transportType", required = false) String transportType) {

        TransportType tt = parseTransportType(transportType);
        List<Trip> results = tripService.searchTrips(departure, arrival, date, tt);

        String depT = departure != null ? departure.trim() : "";
        String arrT = arrival != null ? arrival.trim() : "";
        if (results.isEmpty() && (!depT.isEmpty() || !arrT.isEmpty())) {
            String payload = String.format(
                    "{\"dep\":\"%s\",\"arr\":\"%s\",\"date\":%s}",
                    escapeJson(depT),
                    escapeJson(arrT),
                    date != null ? "\"" + date + "\"" : "null");
            analyticsEventService.record(AnalyticsEventType.SEARCH_NO_RESULT, null, payload);
        }

        return results.stream()
                .map(tripMapper::toDto)
                .collect(Collectors.toList());
    }

    private static TransportType parseTransportType(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return TransportType.valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private static String escapeJson(String s) {
        if (s == null) {
            return "";
        }
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    @GetMapping("/my-trips")
    public List<TripResponseDTO> getMyTrips() {
        return tripService.findMyTrips().stream()
                .map(tripMapper::toDto)
                .collect(Collectors.toList());
    }
}