package com.mobili.backend.api.admin;

import java.time.LocalDate;
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
import com.mobili.backend.module.admin.dto.DailyRegistrationStatsResponse;
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
@RequestMapping("/admin")
@RequiredArgsConstructor
public class AdminController {

    private static final Logger log = LoggerFactory.getLogger(AdminController.class);

    private final UserService userService;
    private final PartnerService partnerService;
    private final AdminService adminService;
    private final TripStatisticsService tripStatisticsService;
    private final UserMapper userMapper;
    private final PartnerMapper partnerMapper;

    @PatchMapping("/partners/{id}/approve")
    public ResponseEntity<Void> approvePartner(@PathVariable Long id) {
        partnerService.approvePartner(id);
        return ResponseEntity.ok().build();
    }

    @PatchMapping("/partners/{id}/reject")
    public ResponseEntity<Void> rejectPartner(
            @PathVariable Long id,
            @org.springframework.web.bind.annotation.RequestBody java.util.Map<String, String> body) {
        partnerService.rejectPartner(id, body.get("reason"));
        return ResponseEntity.ok().build();
    }

    // 💡 AJOUT : Récupérer tous les utilisateurs pour le tableau Angular gogogo
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
     * Comptes créés par l’inscription chauffeur covoiturage (particuliers,
     * rattachement technique au pool) :
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
                        u.getCovoiturageDriverPhotoUrl(),
                        u.getCreatedAt()))
                .toList();
        return ResponseEntity.ok(list);
    }

    // Activer/Désactiver l'accès au site
    @PatchMapping("/users/{id}/status")
    public ResponseEntity<Void> updateUserStatus(@PathVariable Long id, @RequestParam boolean enabled) {
        userService.toggleUserStatus(id, enabled);
        return ResponseEntity.ok().build();
    }

    /**
     * Rattacher un utilisateur (ex. chauffeur salarié) à une compagnie ;
     * {@code partnerId} absent = retirer.
     */
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
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(required = false) Integer days) {
        log.info("GET /v1/admin/analytics/recent-events — limit={}, days={}", limit, days);
        return ResponseEntity.ok(adminService.getRecentAnalyticsEvents(limit, days));
    }

    /** Top exceptions serveur par fréquence sur la période — diagnostic rapide d'un incident. */
    @GetMapping("/analytics/top-errors")
    public ResponseEntity<List<com.mobili.backend.module.admin.dto.TopErrorEntryResponse>> getTopErrors(
            @RequestParam(defaultValue = "7") int days,
            @RequestParam(defaultValue = "10") int limit) {
        log.info("GET /v1/admin/analytics/top-errors — days={}, limit={}", days, limit);
        return ResponseEntity.ok(adminService.getTopErrors(days, limit));
    }

    @GetMapping("/stats/trip-analytics")
    public ResponseEntity<AdminTripStatsResponse> getTripAnalytics(
            @RequestParam(defaultValue = "WEEK") TripStatsPeriod period,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate toDate,
            @RequestParam(required = false) Long stationId,
            @RequestParam(required = false) Long partnerId) {
        log.info("GET /v1/admin/stats/trip-analytics — period={}, fromDate={}, toDate={}, stationId={}, partnerId={}",
                period, fromDate, toDate, stationId, partnerId);
        return ResponseEntity.ok(tripStatisticsService.forPeriod(period, fromDate, toDate, stationId, partnerId));
    }

    /** Liste des gares toutes compagnies confondues — pour le filtre des Stats métier. */
    @GetMapping("/stats/stations")
    public ResponseEntity<List<com.mobili.backend.module.admin.dto.AdminStationOptionResponse>> getStationOptions() {
        return ResponseEntity.ok(adminService.getStationOptions());
    }

    @GetMapping("/stats/tickets/list")
    public ResponseEntity<List<com.mobili.backend.module.admin.dto.AdminTicketListItemResponse>> getTicketList(
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate toDate,
            @RequestParam(required = false) String search) {
        return ResponseEntity.ok(adminService.getTicketList(fromDate, toDate, search));
    }

    @GetMapping("/stats/bookings/list")
    public ResponseEntity<List<com.mobili.backend.module.admin.dto.AdminBookingListItemResponse>> getBookingList(
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate toDate,
            @RequestParam(required = false) String search) {
        return ResponseEntity.ok(adminService.getBookingList(fromDate, toDate, search));
    }

    // Frais Mobili (forfait), commission prelevee sur la compagnie, et net revenant a la
    // compagnie, par reservation payee — voir AdminService.getTransactionList.
    @GetMapping("/stats/transactions/list")
    public ResponseEntity<List<com.mobili.backend.module.admin.dto.AdminTransactionResponse>> getTransactionList(
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate toDate,
            @RequestParam(required = false) String search) {
        return ResponseEntity.ok(adminService.getTransactionList(fromDate, toDate, search));
    }

    @GetMapping("/stats/trips/list")
    public ResponseEntity<List<com.mobili.backend.module.admin.dto.AdminTripListItemResponse>> getTripList(
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate toDate,
            @RequestParam(required = false) String search) {
        return ResponseEntity.ok(adminService.getTripList(fromDate, toDate, search));
    }

    @GetMapping("/stats/trips-with-sales-count")
    public ResponseEntity<com.mobili.backend.module.admin.dto.TripsWithSalesCountResponse> getTripsWithSalesCount(
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return ResponseEntity.ok(adminService.getTripsWithSalesCount(fromDate, toDate));
    }

    @GetMapping("/stats/covoiturage")
    public ResponseEntity<com.mobili.backend.module.admin.dto.DailyCovoiturageStatsResponse> getCovoiturageStats(
            @RequestParam(defaultValue = "30") int days,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) LocalDate toDate) {
        return ResponseEntity.ok(adminService.getCovoiturageStats(days, fromDate, toDate));
    }

    @GetMapping("/stats/registrations")
    public ResponseEntity<DailyRegistrationStatsResponse> getRegistrationStats(
            @RequestParam(defaultValue = "30") int days,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate toDate) {
        return ResponseEntity.ok(adminService.getRegistrationStats(days, fromDate, toDate));
    }

    @GetMapping("/stats/partners")
    public ResponseEntity<com.mobili.backend.module.admin.dto.DailyPartnerStatsResponse> getPartnerStats(
            @RequestParam(defaultValue = "30") int days,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate toDate) {
        return ResponseEntity.ok(adminService.getPartnerStats(days, fromDate, toDate));
    }

    @GetMapping("/stats/tickets")
    public ResponseEntity<com.mobili.backend.module.admin.dto.DailyTicketStatsResponse> getTicketStats(
            @RequestParam(defaultValue = "30") int days,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate toDate) {
        return ResponseEntity.ok(adminService.getTicketStats(days, fromDate, toDate));
    }

    @PatchMapping("/users/{id}/covoiturage-kyc")
    public ResponseEntity<Void> updateCovoiturageKyc(
            @PathVariable Long id,
            @RequestParam String status) {
        userService.updateCovoiturageKycStatus(id, status);
        return ResponseEntity.ok().build();
    }
}
