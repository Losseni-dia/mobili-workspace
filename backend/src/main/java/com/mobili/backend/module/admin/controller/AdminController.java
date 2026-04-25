package com.mobili.backend.module.admin.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.module.admin.dto.AdminStatsResponse;
import com.mobili.backend.module.admin.dto.AdminTripStatsResponse;
import com.mobili.backend.module.admin.dto.AnalyticsRecentEventResponse;
import com.mobili.backend.module.admin.dto.AnalyticsSummaryResponse;
import com.mobili.backend.module.admin.dto.DailyLoginStatsResponse;
import com.mobili.backend.module.admin.model.TripStatsPeriod;
import com.mobili.backend.module.admin.service.TripStatisticsService;
import com.mobili.backend.module.admin.dto.CovoiturageSoloDriverAdminItem;
import com.mobili.backend.module.admin.dto.PartnerAdminResponse;
import com.mobili.backend.module.admin.dto.UserAdminResponse;
import com.mobili.backend.module.admin.service.AdminService;
import com.mobili.backend.module.partner.dto.mapper.PartnerMapper;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.user.dto.mapper.UserMapper;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;

import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestController
@RequestMapping("/v1/admin")
@RequiredArgsConstructor
public class AdminController {

    private static final Logger log = LoggerFactory.getLogger(AdminController.class);

    private final UserService userService;
    private final PartnerService partnerService;
    private final AdminService adminService;
    private final TripStatisticsService tripStatisticsService;
    private final UserMapper userMapper;
    private final PartnerMapper partnerMapper;



    // 💡 AJOUT : Récupérer tous les utilisateurs pour le tableau Angular
    @GetMapping("/users")
    public ResponseEntity<List<UserAdminResponse>> getAllUsers() {
        List<User> users = userService.findAllUsers();

        // 💡 C'est ici que la magie opère : on transforme l'entité en DTO
        List<UserAdminResponse> response = users.stream()
                .map(userMapper::toAdminDto)
                .toList();

        return ResponseEntity.ok(response);
    }

  @GetMapping("/partners")
  public ResponseEntity<List<PartnerAdminResponse>> getAllPartners() {
         List<Partner> partners = partnerService.findAll();

        
        List<PartnerAdminResponse> response = partners.stream()
                .map(partnerMapper::toAdminDto)
                .toList();

        return ResponseEntity.ok(response);
    }

    /**
     * Comptes créés par l’inscription chauffeur covoiturage (particuliers, rattachement technique au pool) :
     * affichage admin à côté de la fiche partenaire « pool ».
     */
    @GetMapping("/covoiturage-solo-drivers")
    public ResponseEntity<List<CovoiturageSoloDriverAdminItem>> getCovoiturageSoloDrivers() {
        List<CovoiturageSoloDriverAdminItem> list = userService.findCovoiturageSoloProfileUsersOrderByName().stream()
                .map(u -> new CovoiturageSoloDriverAdminItem(
                        u.getId(),
                        u.getFirstname(),
                        u.getLastname(),
                        u.getEmail(),
                        u.getCovoiturageKycStatus() == null ? null : u.getCovoiturageKycStatus().name(),
                        u.isEnabled(),
                        u.getCovoiturageDriverPhotoUrl()))
                .toList();
        return ResponseEntity.ok(list);
    }

    // Activer/Désactiver l'accès au site
    @PatchMapping("/users/{id}/status")
    public ResponseEntity<Void> updateUserStatus(@PathVariable Long id, @RequestParam boolean enabled) {
        userService.toggleUserStatus(id, enabled);
        return ResponseEntity.ok().build();
    }

    /** Rattacher un utilisateur (ex. chauffeur salarié) à une compagnie ; {@code partnerId} absent = retirer. */
    @PatchMapping("/users/{id}/employer-partner")
    public ResponseEntity<UserAdminResponse> setUserEmployerPartner(
            @PathVariable Long id, @RequestParam(required = false) Long partnerId) {
        userService.setEmployerPartnerForUser(id, partnerId);
        User u = userService.findById(id);
        return ResponseEntity.ok(userMapper.toAdminDto(u));
    }

    // Activer/Désactiver le droit de publier des trajets
    @PatchMapping("/partners/{id}/toggle")
    public ResponseEntity<Void> togglePartnerStatus(@PathVariable Long id) {
        partnerService.toggleStatus(id);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/stats")
    public ResponseEntity<AdminStatsResponse> getStats() {
        log.info("GET /v1/admin/stats — chargement des statistiques globales");
        AdminStatsResponse stats = adminService.getGlobalStats();
        log.info("GET /v1/admin/stats — réponse: {}", stats);
        return ResponseEntity.ok(stats);
    }

    @GetMapping("/stats/daily-logins")
    public ResponseEntity<DailyLoginStatsResponse> getDailyLoginStats(
            @RequestParam(defaultValue = "30") int days) {
        log.info("GET /v1/admin/stats/daily-logins — période={}j", days);
        DailyLoginStatsResponse response = adminService.getDailyLoginStats(days);
        log.info("GET /v1/admin/stats/daily-logins — today: logins={}, uniques={}, history={}j",
                response.todayTotalLogins(), response.todayUniqueUsers(), response.history().size());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/analytics/summary")
    public ResponseEntity<AnalyticsSummaryResponse> getAnalyticsSummary(
            @RequestParam(defaultValue = "7") int days) {
        log.info("GET /v1/admin/analytics/summary — période={}j", days);
        AnalyticsSummaryResponse response = adminService.getAnalyticsSummary(days);
        log.info("GET /v1/admin/analytics/summary — {} entrées de type", response.byType().size());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/analytics/recent-events")
    public ResponseEntity<List<AnalyticsRecentEventResponse>> getRecentAnalyticsEvents(
            @RequestParam(defaultValue = "50") int limit) {
        log.info("GET /v1/admin/analytics/recent-events — limit={}", limit);
        return ResponseEntity.ok(adminService.getRecentAnalyticsEvents(limit));
    }

    @GetMapping("/stats/trip-analytics")
    public ResponseEntity<AdminTripStatsResponse> getTripAnalytics(
            @RequestParam(defaultValue = "WEEK") TripStatsPeriod period) {
        log.info("GET /v1/admin/stats/trip-analytics — period={}", period);
        return ResponseEntity.ok(tripStatisticsService.forPeriod(period));
    }
}
