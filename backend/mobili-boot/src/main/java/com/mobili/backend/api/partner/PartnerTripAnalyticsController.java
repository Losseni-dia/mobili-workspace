package com.mobili.backend.api.partner;

import java.time.LocalDate;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.infrastructure.security.authentication.StationPrincipal;
import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.admin.dto.AdminTripStatsResponse;
import com.mobili.backend.module.admin.model.TripStatsPeriod;
import com.mobili.backend.module.admin.service.TripStatisticsService;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * "Stats métier" côté partenaire — même moteur que l'admin (TripStatisticsService), scopé de
 * force à la compagnie courante : jamais de paramètre partnerId côté client, jamais d'accès aux
 * données d'une autre compagnie. Un utilisateur "gare" voit sa gare uniquement (stationId forcé),
 * un dirigeant voit toutes ses gares par défaut avec un filtre gare optionnel — même règle que
 * PartnerDashboardController.getStats().
 */
@Slf4j
@RestController
@RequestMapping("/partenaire/stats")
@PreAuthorize("hasAnyAuthority('ROLE_PARTNER','ROLE_GARE','ROLE_STATION')")
@RequiredArgsConstructor
public class PartnerTripAnalyticsController {

    private final TripStatisticsService tripStatisticsService;
    private final PartnerService partnerService;

    @GetMapping("/trip-analytics")
    public ResponseEntity<AdminTripStatsResponse> getTripAnalytics(
            @RequestParam(defaultValue = "WEEK") TripStatsPeriod period,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate,
            @RequestParam(required = false) Long stationId,
            Authentication authentication) {
        Partner partner = partnerService.getCurrentPartnerForOperations();

        // Un compte "gare" ne voit jamais que sa propre gare — le stationId client est ignoré,
        // pas simplement validé (même défense en profondeur que PartnerDashboardController).
        Object rawPrincipal = authentication.getPrincipal();
        if (rawPrincipal instanceof StationPrincipal sp) {
            stationId = sp.getStationId();
        } else if (rawPrincipal instanceof UserPrincipal up && up.getStationId() != null) {
            stationId = up.getStationId();
        }

        log.info("GET /v1/partenaire/stats/trip-analytics — partnerId={}, period={}, stationId={}",
                partner.getId(), period, stationId);
        return ResponseEntity.ok(
                tripStatisticsService.forPeriod(period, fromDate, toDate, stationId, partner.getId()));
    }
}
