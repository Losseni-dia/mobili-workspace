package com.mobili.backend.api.passenger.trip;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.trip.dto.TripRatingRequest;
import com.mobili.backend.module.trip.dto.TripRatingResponse;
import com.mobili.backend.module.trip.service.TripRatingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/trips")
@RequiredArgsConstructor
public class TripRatingController {

    private final TripRatingService tripRatingService;

    @PostMapping("/{tripId}/ratings")
    public ResponseEntity<TripRatingResponse> rate(
            @PathVariable Long tripId,
            @Valid @RequestBody TripRatingRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(tripRatingService.rate(tripId, request, principal));
    }

    @GetMapping("/{tripId}/ratings/mine")
    public ResponseEntity<Boolean> hasRated(
            @PathVariable Long tripId,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(tripRatingService.hasRated(tripId, principal));
    }

    @GetMapping("/{tripId}/ratings/average")
    public ResponseEntity<Map<String, Object>> getAverage(
            @PathVariable Long tripId) {
        Double avg = tripRatingService.getAverageForTrip(tripId);
        long count = tripRatingService.countForTrip(tripId);
        return ResponseEntity.ok(Map.of(
                "average", avg != null ? avg : 0.0,
                "count", count));
    }
}
