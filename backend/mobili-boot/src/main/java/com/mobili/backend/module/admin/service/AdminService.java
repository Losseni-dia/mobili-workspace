package com.mobili.backend.module.admin.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mobili.backend.module.admin.dto.AdminStatsResponse;
import com.mobili.backend.module.admin.dto.AnalyticsRecentEventResponse;
import com.mobili.backend.module.admin.dto.AnalyticsSummaryResponse;
import com.mobili.backend.module.admin.dto.AnalyticsSummaryResponse.CountByType;
import com.mobili.backend.module.admin.dto.DailyLoginStatsResponse;
import com.mobili.backend.module.admin.dto.DailyLoginStatsResponse.DayEntry;
import com.mobili.backend.module.admin.repository.LoginEventRepository;
import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.entity.AppAnalyticsEvent;
import com.mobili.backend.module.analytics.repository.AppAnalyticsEventRepository;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.partner.repository.PartnerRepository;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class AdminService {

    private static final Logger log = LoggerFactory.getLogger(AdminService.class);
    private static final DateTimeFormatter ISO_LOCAL = DateTimeFormatter.ISO_LOCAL_DATE_TIME;
    /** Instance locale : Spring Boot 4 n’expose pas toujours un bean {@code ObjectMapper}. */
    private static final ObjectMapper JSON = new ObjectMapper();

    private final UserRepository userRepository;
    private final PartnerRepository partnerRepository;
    private final BookingRepository bookingRepository;
    private final TripRepository tripRepository;
    private final LoginEventRepository loginEventRepository;
    private final AppAnalyticsEventRepository appAnalyticsEventRepository;

    @Transactional(readOnly = true)
    public AdminStatsResponse getGlobalStats() {
        long totalUsers = userRepository.count();
        long totalPartners = partnerRepository.count();
        long totalTrips = tripRepository.count();
        long activeBookings = bookingRepository.count();

        Double revenue = bookingRepository.sumTotalRevenue();
        double totalRevenue = revenue != null ? revenue : 0.0;

        log.info("[AdminStats] users={}, partners={}, trips={}, bookings={}, revenue={}",
                totalUsers, totalPartners, totalTrips, activeBookings, totalRevenue);

        return new AdminStatsResponse(
                totalUsers,
                totalPartners,
                totalTrips,
                activeBookings,
                totalRevenue
        );
    }

    @Transactional(readOnly = true)
    public DailyLoginStatsResponse getDailyLoginStats(int days) {
        LocalDate today = LocalDate.now();
        LocalDate from = today.minusDays(days - 1);

        long todayTotal = loginEventRepository.countByLoginDate(today);
        long todayUnique = loginEventRepository.countDistinctUsersByDate(today);

        log.info("[DailyLogin] Aujourd'hui: totalLogins={}, uniqueUsers={}", todayTotal, todayUnique);

        List<Object[]> raw = loginEventRepository.dailyStatsBetween(from, today);

        List<DayEntry> history = raw.stream()
                .map(row -> {
                    LocalDate date = (LocalDate) row[0];
                    long total = (Long) row[1];
                    long unique = (Long) row[2];
                    log.debug("[DailyLogin] date={}, logins={}, uniques={}", date, total, unique);
                    return new DayEntry(date, total, unique);
                })
                .toList();

        log.info("[DailyLogin] Historique chargé: {} jours (du {} au {})", history.size(), from, today);

        return new DailyLoginStatsResponse(todayTotal, todayUnique, history);
    }

    @Transactional(readOnly = true)
    public AnalyticsSummaryResponse getAnalyticsSummary(int days) {
        if (days < 1) {
            days = 1;
        }
        if (days > 365) {
            days = 365;
        }
        LocalDateTime from = LocalDateTime.now().minusDays(days);
        List<Object[]> rows = appAnalyticsEventRepository.countByTypeSince(from);
        log.info("[Analytics] Agrégat sur {}j : {} type(s) distincts", days, rows.size());
        List<CountByType> byType = rows.stream()
                .map(r -> new CountByType((AnalyticsEventType) r[0], (Long) r[1]))
                .toList();
        return new AnalyticsSummaryResponse(from, days, byType);
    }

    @Transactional(readOnly = true)
    public List<AnalyticsRecentEventResponse> getRecentAnalyticsEvents(int limit) {
        if (limit < 1) {
            limit = 1;
        }
        if (limit > 200) {
            limit = 200;
        }
        List<AppAnalyticsEvent> list = appAnalyticsEventRepository.findAllByOrderByCreatedAtDesc(
                PageRequest.of(0, limit));
        log.info("[Analytics] Journal détaillé : {} entrées", list.size());
        return list.stream().map(this::toRecentEvent).toList();
    }

    private AnalyticsRecentEventResponse toRecentEvent(AppAnalyticsEvent e) {
        String at = e.getCreatedAt() != null ? e.getCreatedAt().format(ISO_LOCAL) : "";
        return new AnalyticsRecentEventResponse(
                e.getId(),
                at,
                e.getEventType(),
                formatEventDetail(e.getEventType(), e.getPayload()));
    }

    private String formatEventDetail(AnalyticsEventType type, String payload) {
        if (payload == null || payload.isBlank()) {
            return "—";
        }
        String trimmed = payload.length() > 500 ? payload.substring(0, 500) + "…" : payload;
        try {
            JsonNode n = JSON.readTree(payload);
            return switch (type) {
                case FAILED_LOGIN -> formatFailedLoginDetail(n);
                case SEARCH_NO_RESULT -> formatSearchDetail(n);
                case BOOKING_CREATED -> formatBookingCreatedDetail(n);
                case BOOKING_PAID -> formatBookingPaidDetail(n);
                case TRIP_PUBLISHED -> formatTripPublishedDetail(n);
                case SERVER_ERROR -> formatServerErrorDetail(n);
            };
        } catch (Exception ex) {
            return trimmed;
        }
    }

    private static String formatFailedLoginDetail(JsonNode n) {
        String r = text(n, "reason");
        if (r == null) {
            return "Tentative refusée";
        }
        return switch (r) {
            case "NOT_FOUND" -> "Identifiant de connexion inconnu";
            case "ACCOUNT_DISABLED" -> "Compte désactivé";
            case "BAD_PASSWORD" -> "Mot de passe incorrect";
            default -> "Raison : " + r;
        };
    }

    private static String formatSearchDetail(JsonNode n) {
        String dep = text(n, "dep");
        String arr = text(n, "arr");
        JsonNode d = n.get("date");
        String dateStr = d == null || d.isNull() ? "toutes dates" : d.asText("?");
        if ((dep == null || dep.isEmpty()) && (arr == null || arr.isEmpty())) {
            return "Recherche sans résultat (date : " + dateStr + ")";
        }
        return "Départ « " + nullToDash(dep) + " » → Arrivée « " + nullToDash(arr) + " » (date : " + dateStr + ")";
    }

    private static String formatBookingCreatedDetail(JsonNode n) {
        return "Réservation #" + n.path("bookingId").asText("?")
                + " · Trajet #" + n.path("tripId").asText("?");
    }

    private static String formatBookingPaidDetail(JsonNode n) {
        String source = text(n, "source");
        String src = source != null ? " · Paiement : " + source : "";
        return "Réservation #" + n.path("bookingId").asText("?") + src;
    }

    private static String formatTripPublishedDetail(JsonNode n) {
        return "Trajet #" + n.path("tripId").asText("?")
                + " · Partenaire (id) #" + n.path("partnerId").asText("?");
    }

    private static String formatServerErrorDetail(JsonNode n) {
        String ex = text(n, "exception");
        if (ex == null) {
            ex = text(n, "ex");
        }
        return ex != null ? "Exception : " + ex : "Erreur serveur";
    }

    private static String text(JsonNode n, String field) {
        JsonNode v = n.get(field);
        if (v == null || v.isNull() || v.isMissingNode()) {
            return null;
        }
        String s = v.asText();
        return s.isEmpty() ? null : s;
    }

    private static String nullToDash(String s) {
        return s == null || s.isEmpty() ? "—" : s;
    }
}
