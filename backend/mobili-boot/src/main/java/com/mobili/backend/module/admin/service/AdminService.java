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
import com.mobili.backend.module.admin.dto.DailyPartnerStatsResponse;
import com.mobili.backend.module.admin.dto.DailyRegistrationStatsResponse;
import com.mobili.backend.module.admin.dto.DailyTicketStatsResponse;
import com.mobili.backend.module.admin.dto.TopErrorEntryResponse;
import com.mobili.backend.module.admin.repository.LoginEventRepository;
import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.entity.AppAnalyticsEvent;
import com.mobili.backend.module.analytics.repository.AppAnalyticsEventRepository;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;
import com.mobili.backend.module.booking.ticket.util.TicketSegmentUtil;
import com.mobili.backend.module.partner.repository.PartnerRepository;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class AdminService {

    private static final Logger log = LoggerFactory.getLogger(AdminService.class);
    private static final DateTimeFormatter ISO_LOCAL = DateTimeFormatter.ISO_LOCAL_DATE_TIME;
    /**
     * Instance locale : Spring Boot 4 n’expose pas toujours un bean
     * {@code ObjectMapper}.
     */
    private static final ObjectMapper JSON = new ObjectMapper();

    private final UserRepository userRepository;
    private final PartnerRepository partnerRepository;
    private final BookingRepository bookingRepository;
    private final TripRepository tripRepository;
    private final LoginEventRepository loginEventRepository;
    private final AppAnalyticsEventRepository appAnalyticsEventRepository;
    private final TicketRepository ticketRepository;
    private final StationRepository stationRepository;



    @Transactional(readOnly = true)
    public DailyRegistrationStatsResponse getRegistrationStats(int days, LocalDate fromDate, LocalDate toDate) {
        LocalDate today = LocalDate.now();
        LocalDateTime from;
        LocalDateTime to;
        if (fromDate != null && toDate != null) {
            from = fromDate.atStartOfDay();
            to = toDate.atTime(23, 59, 59);
        } else {
            if (days < 1)
                days = 1;
            if (days > 365)
                days = 365;
            from = today.minusDays(days - 1).atStartOfDay();
            to = LocalDateTime.now();
        }

        long todayCount = userRepository.countByCreatedAtDate(today);
        long totalUsers = userRepository.count();

        List<Object[]> raw = userRepository.dailyRegistrationsBetween(from, to);
        List<DailyRegistrationStatsResponse.DayEntry> history = raw.stream()
                .map(row -> {
                    Object col0 = row[0];
                    LocalDate date;
                    if (col0 instanceof java.sql.Date sqlDate) {
                        date = sqlDate.toLocalDate();
                    } else if (col0 instanceof LocalDate ld) {
                        date = ld;
                    } else {
                        date = LocalDate.parse(col0.toString());
                    }
                    return new DailyRegistrationStatsResponse.DayEntry(date, ((Number) row[1]).longValue());
                })
                .toList();
        return new DailyRegistrationStatsResponse(todayCount, totalUsers, history);
    }

    @Transactional(readOnly = true)
    public DailyPartnerStatsResponse getPartnerStats(int days, LocalDate fromDate, LocalDate toDate) {
        LocalDate today = LocalDate.now();
        LocalDateTime from;
        LocalDateTime to;
        if (fromDate != null && toDate != null) {
            from = fromDate.atStartOfDay();
            to = toDate.atTime(23, 59, 59);
        } else {
            if (days < 1)
                days = 1;
            if (days > 365)
                days = 365;
            from = today.minusDays(days - 1).atStartOfDay();
            to = LocalDateTime.now();
        }

        long todayCount = partnerRepository.countByCreatedAtDate(today);
        long totalPartners = partnerRepository.count();

        List<Object[]> raw = partnerRepository.dailyPartnersRegisteredBetween(from, to);
        List<DailyPartnerStatsResponse.DayEntry> history = raw.stream()
                .map(row -> {
                    Object col0 = row[0];
                    LocalDate date;
                    if (col0 instanceof java.sql.Date sqlDate) {
                        date = sqlDate.toLocalDate();
                    } else if (col0 instanceof LocalDate ld) {
                        date = ld;
                    } else {
                        date = LocalDate.parse(col0.toString());
                    }
                    return new DailyPartnerStatsResponse.DayEntry(date, ((Number) row[1]).longValue());
                })
                .toList();
        return new DailyPartnerStatsResponse(todayCount, totalPartners, history);
    }

    @Transactional(readOnly = true)
    public DailyTicketStatsResponse getTicketStats(int days, LocalDate fromDate, LocalDate toDate) {
        LocalDate today = LocalDate.now();
        LocalDateTime from;
        LocalDateTime to;
        if (fromDate != null && toDate != null) {
            from = fromDate.atStartOfDay();
            to = toDate.atTime(23, 59, 59);
        } else {
            if (days < 1)
                days = 1;
            if (days > 365)
                days = 365;
            from = today.minusDays(days - 1).atStartOfDay();
            to = LocalDateTime.now();
        }

        long todayCount = ticketRepository.countByBookingDateDate(today);
        long totalTickets = ticketRepository.countActiveTickets();

        List<Object[]> raw = ticketRepository.dailyTicketsBetween(from, to);
        List<DailyTicketStatsResponse.DayEntry> history = raw.stream()
                .map(row -> {
                    Object col0 = row[0];
                    LocalDate date;
                    if (col0 instanceof java.sql.Date sqlDate) {
                        date = sqlDate.toLocalDate();
                    } else if (col0 instanceof LocalDate ld) {
                        date = ld;
                    } else {
                        date = LocalDate.parse(col0.toString());
                    }
                    return new DailyTicketStatsResponse.DayEntry(date, ((Number) row[1]).longValue());
                })
                .toList();
        return new DailyTicketStatsResponse(todayCount, totalTickets, history);
    }

    @Transactional(readOnly = true)
    public AdminStatsResponse getGlobalStats() {
        long totalUsers = userRepository.count();
        long totalPartners = partnerRepository.count();
        long totalTrips = tripRepository.count();
        java.time.LocalDateTime yearStart = java.time.LocalDateTime.of(java.time.LocalDate.now().getYear(), 1, 1, 0, 0);
        java.time.LocalDateTime yearEnd = java.time.LocalDateTime.of(java.time.LocalDate.now().getYear(), 12, 31, 23, 59, 59);
        long totalTripsThisYear = tripRepository.countByDepartureDateTimeBetween(yearStart, yearEnd);
        long activeBookings = bookingRepository.count();
        long totalTickets = ticketRepository.countActiveTickets();

        // totalRevenue = revenueOnline + revenueOffline, TOUJOURS — jamais recalculé séparément
        // via une définition de statut différente (l'ancien sumTotalRevenue() sommait TOUTE
        // réservation non-CANCELLED, y compris PENDING/EXPIRED/AWAITING_PAYMENT jamais payées,
        // un périmètre plus large et incohérent avec la répartition Via Mobili/Au guichet
        // affichée juste en dessous). Avec cette définition unique, une vente guichet est
        // TOUJOURS comptée dans le total affiché, par construction — plus de risque qu'elle
        // paraisse "juste visible" dans la répartition sans être reflétée dans le total.
        Double revenueOnlineRaw = bookingRepository.sumRevenueOnline();
        Double revenueOfflineRaw = bookingRepository.sumRevenueOffline();
        double revenueOnline = revenueOnlineRaw != null ? revenueOnlineRaw : 0.0;
        double revenueOffline = revenueOfflineRaw != null ? revenueOfflineRaw : 0.0;
        double totalRevenue = revenueOnline + revenueOffline;

        log.info("[AdminStats] users={}, partners={}, trips={}, bookings={}, tickets={}, revenue={}",
                totalUsers, totalPartners, totalTrips, activeBookings, totalTickets, totalRevenue);

        return new AdminStatsResponse(
                totalUsers,
                totalPartners,
                totalTrips,
                totalTripsThisYear,
                totalTickets,
                activeBookings,
                totalRevenue,
                revenueOnline,
                revenueOffline);
    }

    @Transactional(readOnly = true)
    public List<com.mobili.backend.module.admin.dto.AdminTicketListItemResponse> getTicketList(
            LocalDate fromDate, LocalDate toDate, String search) {
        LocalDateTime from = fromDate != null ? fromDate.atStartOfDay() : LocalDate.now().minusDays(29).atStartOfDay();
        LocalDateTime to = toDate != null ? toDate.atTime(23, 59, 59) : LocalDateTime.now();

        List<com.mobili.backend.module.booking.ticket.entity.Ticket> tickets = ticketRepository.findForAdminList(from,
                to, search);

        return tickets.stream()
                .map(t -> new com.mobili.backend.module.admin.dto.AdminTicketListItemResponse(
                        t.getId(),
                        t.getTicketNumber(),
                        t.getPassengerName(),
                        TicketSegmentUtil.resolveRouteLabel(t),
                        t.getTrip().getPartner() != null ? t.getTrip().getPartner().getName() : "—",
                        t.getTrip().getStation() != null ? t.getTrip().getStation().getName() : "—",
                        t.getBookingDate(),
                        t.getTrip() != null ? t.getTrip().getDepartureDateTime() : null,
                        t.getAmountPaid(),
                        t.getStatus() != null ? t.getStatus().name() : "—",
                        t.getSeatNumber(),
                        t.isScanned(),
                        t.getBooking() != null && t.getBooking().getStatus() != null
                                ? t.getBooking().getStatus().name()
                                : null))
                .toList();
    }



    @Transactional(readOnly = true)
    public List<com.mobili.backend.module.admin.dto.AdminBookingListItemResponse> getBookingList(
            LocalDate fromDate, LocalDate toDate, String search) {
        LocalDateTime from = fromDate != null ? fromDate.atStartOfDay() : LocalDate.now().minusDays(29).atStartOfDay();
        LocalDateTime to = toDate != null ? toDate.atTime(23, 59, 59) : LocalDateTime.now();

        List<com.mobili.backend.module.booking.booking.entity.Booking> bookings = bookingRepository
                .findForAdminList(from, to, search);

        return bookings.stream()
                .map(b -> new com.mobili.backend.module.admin.dto.AdminBookingListItemResponse(
                        b.getId(),
                        b.getReference(),
                        b.getCustomer().getFirstname() + " " + b.getCustomer().getLastname(),
                        com.mobili.backend.module.booking.booking.util.BookingSegmentUtil.resolveRouteLabel(b),
                        b.getTrip().getPartner() != null ? b.getTrip().getPartner().getName() : "—",
                        b.getTrip().getStation() != null ? b.getTrip().getStation().getName() : "—",
                        b.getBookingDate(),
                        b.getTrip() != null ? b.getTrip().getDepartureDateTime() : null,
                        b.getNumberOfSeats(),
                        b.getTotalPrice(),
                        b.getGrossAmount() + (b.getServiceFee() != null ? b.getServiceFee() : 0),
                        b.getStatus() != null ? b.getStatus().name() : "—"))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<com.mobili.backend.module.admin.dto.AdminTransactionResponse> getTransactionList(
            LocalDate fromDate, LocalDate toDate, String search) {
        LocalDateTime from = fromDate != null ? fromDate.atStartOfDay() : LocalDate.now().minusDays(29).atStartOfDay();
        LocalDateTime to = toDate != null ? toDate.atTime(23, 59, 59) : LocalDateTime.now();

        List<com.mobili.backend.module.booking.booking.entity.Booking> bookings = bookingRepository
                .findConfirmedForAdminTransactions(from, to, search);

        return bookings.stream()
                .map(b -> {
                    // Exclut les tickets ANNULÉ individuellement (annulation partielle) — voir
                    // Booking.getActiveTicketsAmount()/getActiveLuggageFee(), seule
                    // implémentation de ce calcul dans tout le backend (même formule que
                    // BookingService.findMyPartnerTransactionsInRange côté partenaire).
                    int commissionTotal = b.getTickets().stream()
                            .filter(t -> t.getStatus() != com.mobili.backend.module.booking.ticket.entity.TicketStatus.ANNULÉ)
                            .mapToInt(t -> t.getCommissionAmount() != null ? t.getCommissionAmount() : 0)
                            .sum();
                    double ticketsAmount = b.getActiveTicketsAmount();
                    int serviceFee = b.getServiceFee() != null ? b.getServiceFee() : 0;
                    double luggageFee = b.getActiveLuggageFee();
                    double companyNet = ticketsAmount + luggageFee - commissionTotal;
                    var partner = b.getTrip().getPartner();
                    var station = b.getTrip().getStation();

                    return new com.mobili.backend.module.admin.dto.AdminTransactionResponse(
                            b.getId(),
                            b.getReference(),
                            b.getBookingDate(),
                            b.getTrip() != null ? b.getTrip().getDepartureDateTime() : null,
                            b.getCustomer().getFirstname() + " " + b.getCustomer().getLastname(),
                            com.mobili.backend.module.booking.booking.util.BookingSegmentUtil.resolveRouteLabel(b),
                            partner != null ? partner.getId() : null,
                            partner != null ? partner.getName() : "—",
                            station != null ? station.getId() : null,
                            station != null ? station.getName() : "—",
                            ticketsAmount,
                            serviceFee,
                            luggageFee,
                            commissionTotal,
                            companyNet,
                            // Doit suivre l'annulation partielle comme ticketsAmount/luggageFee
                            // ci-dessus (b.getTotalPrice() brut restait figé au montant de vente
                            // initial même après annulation d'un ou plusieurs tickets — décalage
                            // avec companyNet/commissionTotal qui, eux, se réduisaient déjà).
                            ticketsAmount + serviceFee + luggageFee,
                            b.getStatus() != null ? b.getStatus().name() : "—");
                })
                .toList();
    }

    /** Toutes les gares, toutes compagnies confondues — filtre de la page Stats métier. */
    @Transactional(readOnly = true)
    public List<com.mobili.backend.module.admin.dto.AdminStationOptionResponse> getStationOptions() {
        return stationRepository.findAll().stream()
                .map(s -> new com.mobili.backend.module.admin.dto.AdminStationOptionResponse(
                        s.getId(),
                        s.getName(),
                        s.getPartner() != null ? s.getPartner().getName() : "—"))
                .sorted(java.util.Comparator.comparing(
                        com.mobili.backend.module.admin.dto.AdminStationOptionResponse::name,
                        String.CASE_INSENSITIVE_ORDER))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<com.mobili.backend.module.admin.dto.AdminTripListItemResponse> getTripList(
            LocalDate fromDate, LocalDate toDate, String search) {
        LocalDateTime from = fromDate != null ? fromDate.atStartOfDay() : LocalDate.now().minusDays(29).atStartOfDay();
        LocalDateTime to = toDate != null ? toDate.atTime(23, 59, 59) : LocalDate.now().plusDays(30).atTime(23, 59, 59);

        List<com.mobili.backend.module.trip.entity.Trip> trips = tripRepository.findForAdminList(from, to, search);

        return trips.stream()
                .map(t -> new com.mobili.backend.module.admin.dto.AdminTripListItemResponse(
                        t.getId(),
                        t.getDepartureCity() + " → " + t.getArrivalCity(),
                        t.getPartner() != null ? t.getPartner().getName() : "—",
                        t.getStation() != null ? t.getStation().getName() : "—",
                        t.getDepartureDateTime(),
                        t.getTotalSeats(),
                        t.getAvailableSeats(),
                        t.getPrice(),
                        t.getStatus() != null ? t.getStatus().name() : "—"))
                .toList();
    }

    @Transactional(readOnly = true)
    public com.mobili.backend.module.admin.dto.DailyCovoiturageStatsResponse getCovoiturageStats(
            int days, LocalDate fromDate, LocalDate toDate) {
        LocalDate today = LocalDate.now();
        LocalDateTime from;
        LocalDateTime to;
        if (fromDate != null && toDate != null) {
            from = fromDate.atStartOfDay();
            to = toDate.atTime(23, 59, 59);
        } else {
            if (days < 1)
                days = 1;
            if (days > 365)
                days = 365;
            from = today.minusDays(days - 1).atStartOfDay();
            to = LocalDateTime.now();
        }

        long todayCount = userRepository.countCovoiturageSoloProfileByCreatedAtDate(today);
        long totalDrivers = userRepository.countCovoiturageSoloProfileTotal();

        List<Object[]> raw = userRepository.dailyCovoiturageRegistrationsBetween(from, to);
        List<com.mobili.backend.module.admin.dto.DailyCovoiturageStatsResponse.DayEntry> history = raw.stream()
                .map(row -> {
                    Object col0 = row[0];
                    LocalDate date;
                    if (col0 instanceof java.sql.Date sqlDate) {
                        date = sqlDate.toLocalDate();
                    } else if (col0 instanceof LocalDate ld) {
                        date = ld;
                    } else {
                        date = LocalDate.parse(col0.toString());
                    }
                    return new com.mobili.backend.module.admin.dto.DailyCovoiturageStatsResponse.DayEntry(
                            date, ((Number) row[1]).longValue());
                })
                .toList();
        return new com.mobili.backend.module.admin.dto.DailyCovoiturageStatsResponse(todayCount, totalDrivers, history);
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
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime from = now.minusDays(days);
        List<Object[]> rows = appAnalyticsEventRepository.countByTypeSince(from);
        log.info("[Analytics] Agrégat sur {}j : {} type(s) distincts", days, rows.size());
        List<CountByType> byType = rows.stream()
                .map(r -> new CountByType((AnalyticsEventType) r[0], (Long) r[1]))
                .toList();

        // Période précédente de même durée, immédiatement avant `from` — pour une variation en %
        // (même principe que Stats métier), jamais fournie ni exploitée pour l'agrégat produit
        // avant ce chantier.
        LocalDateTime prevFrom = from.minusDays(days);
        List<Object[]> prevRows = appAnalyticsEventRepository.countByTypeBetween(prevFrom, from);
        List<CountByType> previousByType = prevRows.stream()
                .map(r -> new CountByType((AnalyticsEventType) r[0], (Long) r[1]))
                .toList();

        return new AnalyticsSummaryResponse(from, days, byType, previousByType);
    }

    @Transactional(readOnly = true)
    public List<AnalyticsRecentEventResponse> getRecentAnalyticsEvents(int limit, Integer days) {
        if (limit < 1) {
            limit = 1;
        }
        if (limit > 200) {
            limit = 200;
        }
        List<AppAnalyticsEvent> list;
        if (days != null && days > 0) {
            LocalDateTime from = LocalDateTime.now().minusDays(days);
            list = appAnalyticsEventRepository.findAllByCreatedAtGreaterThanEqualOrderByCreatedAtDesc(
                    from, PageRequest.of(0, limit));
        } else {
            list = appAnalyticsEventRepository.findAllByOrderByCreatedAtDesc(PageRequest.of(0, limit));
        }
        log.info("[Analytics] Journal détaillé : {} entrées (days={})", list.size(), days);
        return list.stream().map(this::toRecentEvent).toList();
    }

    /**
     * Classement des exceptions serveur (SERVER_ERROR) par fréquence sur la période — diagnostic
     * rapide d'un incident (une même classe qui explose en fréquence pointe vers un bug précis,
     * distinct du journal ligne à ligne qui noie l'info dans les répétitions).
     */
    @Transactional(readOnly = true)
    public List<TopErrorEntryResponse> getTopErrors(int days, int limit) {
        if (days < 1) {
            days = 1;
        }
        if (days > 365) {
            days = 365;
        }
        if (limit < 1) {
            limit = 1;
        }
        if (limit > 50) {
            limit = 50;
        }
        LocalDateTime from = LocalDateTime.now().minusDays(days);
        List<AppAnalyticsEvent> events = appAnalyticsEventRepository
                .findAllByEventTypeAndCreatedAtGreaterThanEqualOrderByCreatedAtDesc(
                        AnalyticsEventType.SERVER_ERROR, from);

        java.util.Map<String, Long> counts = new java.util.LinkedHashMap<>();
        java.util.Map<String, LocalDateTime> lastSeen = new java.util.HashMap<>();
        for (AppAnalyticsEvent e : events) {
            String exClass = "Exception inconnue";
            try {
                JsonNode n = JSON.readTree(e.getPayload());
                String ex = text(n, "exception");
                if (ex != null) {
                    exClass = ex;
                }
            } catch (Exception ignored) {
                // payload absent/illisible — regroupé sous "Exception inconnue"
            }
            counts.merge(exClass, 1L, Long::sum);
            lastSeen.merge(exClass, e.getCreatedAt(),
                    (a, b) -> a != null && (b == null || a.isAfter(b)) ? a : b);
        }
        final int max = limit;
        return counts.entrySet().stream()
                .sorted(java.util.Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(max)
                .map(en -> new TopErrorEntryResponse(en.getKey(), en.getValue(), lastSeen.get(en.getKey())))
                .toList();
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
        String route = text(n, "route");
        String base = ex != null ? "Exception : " + ex : "Erreur serveur";
        return route != null ? base + " · " + route : base;
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
