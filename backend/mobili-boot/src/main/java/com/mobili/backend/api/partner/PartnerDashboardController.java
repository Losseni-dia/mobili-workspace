package com.mobili.backend.api.partner;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.partner.dto.PartnerDashboardResponse;
import com.mobili.backend.module.partner.dto.RecentBookingDTO;
import com.mobili.backend.module.partner.dto.mapper.PartnerMapper;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerDashboardService;
import com.mobili.backend.module.partner.service.PartnerService; // Ton service qui récupère le partenaire actuel
import lombok.RequiredArgsConstructor;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/v1/partenaire/dashboard")
@RequiredArgsConstructor
public class PartnerDashboardController {

    private final PartnerDashboardService dashboardService;
    private final PartnerService partnerService;
    private final PartnerMapper partnerMapper;

    @GetMapping("/stats")
    public ResponseEntity<PartnerDashboardResponse> getStats(
            @RequestParam(required = false) Long stationId,
            @AuthenticationPrincipal UserPrincipal principal) {
        // 1. Récupère le partenaire actuel (Entité)
        Partner partner = partnerService.getCurrentPartnerForOperations();
        if (principal.getStationId() != null) {
            stationId = principal.getStationId();
        }

        // 2. Récupère les données (Map d'objets métier)
        Map<String, Object> rawData = dashboardService.getDashboardData(partner.getId(), stationId);

        // 3. Transformation via MapStruct (Entité Booking -> RecentBookingDTO)
        List<RecentBookingDTO> recentBookings = partnerMapper.toRecentBookingDtoList(
                (List<Booking>) rawData.get("bookingsList"));

        // 4. Construction du DTO de réponse final
        return ResponseEntity.ok(PartnerDashboardResponse.builder()
                .activeTripsCount((long) rawData.get("activeTrips"))
                .totalBookingsCount((long) rawData.get("totalBookings"))
                .totalRevenue((double) rawData.get("totalRevenue"))
                .recentBookings(recentBookings)
                .build());
    }
}