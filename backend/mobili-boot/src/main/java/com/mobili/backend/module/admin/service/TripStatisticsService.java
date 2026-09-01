package com.mobili.backend.module.admin.service;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.admin.dto.AdminTripStatsResponse;
import com.mobili.backend.module.admin.dto.RevenueDonutSliceResponse;
import com.mobili.backend.module.admin.dto.TripStatEntryResponse;
import com.mobili.backend.module.admin.dto.TripStatsDayEntryResponse;
import com.mobili.backend.module.admin.dto.VolumeDonutSliceResponse;
import com.mobili.backend.module.admin.model.TripStatsPeriod;
import com.mobili.backend.module.booking.booking.projection.TripStatsAggrJpa;
import com.mobili.backend.module.booking.booking.projection.TripStatsPerTripJpa;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class TripStatisticsService {

    private final BookingRepository bookingRepository;

    /** Nombre de lignes renvoyées par classement — la page affiche un "top 10" par défaut avec
     *  "Voir plus" côté client jusqu'à cette limite, sans nouvel appel réseau. */
    private static final int TOP_N = 50;

    @Transactional(readOnly = true)
    public AdminTripStatsResponse forPeriod(
            TripStatsPeriod period, LocalDate fromDate, LocalDate toDate, Long stationId, Long partnerId) {
        LocalDateTime to;
        LocalDateTime from;
        if (period == TripStatsPeriod.CUSTOM && fromDate != null && toDate != null) {
            from = fromDate.atStartOfDay();
            to = toDate.atTime(23, 59, 59);
        } else {
            to = LocalDateTime.now();
            from = switch (period) {
                case DAY -> LocalDate.now().atStartOfDay();
                case WEEK -> LocalDate.now().minusDays(6).atStartOfDay();
                case MONTH -> LocalDate.now().minusDays(29).atStartOfDay();
                case YEAR -> LocalDate.now().minusDays(364).atStartOfDay();
                case CUSTOM -> LocalDate.now().minusDays(29).atStartOfDay(); // repli si dates manquantes
            };
        }

        TripStatsAggrJpa agg = bookingRepository.aggregateForTripStats(from, to, stationId, partnerId);
        if (agg == null) {
            agg = new TripStatsAggrJpa(0.0, 0L, 0L, 0.0, 0.0, 0.0);
        }
        double totalRev = agg.getTotalRevenue();
        long totalBook = agg.getTotalBookings();
        long distinctTrips = agg.getDistinctTrips();
        double avg = totalBook > 0 ? totalRev / (double) totalBook : 0.0;

        // Période précédente de même durée, immédiatement avant `from` — pour une variation en
        // % ("+12 % vs période précédente"), jamais affichée si la précédente est vide (évite
        // une div/0 ou un pourcentage absurde du type "+∞ %").
        long durationSeconds = Duration.between(from, to).getSeconds();
        LocalDateTime prevTo = from;
        LocalDateTime prevFrom = from.minusSeconds(durationSeconds);
        TripStatsAggrJpa prevAgg = bookingRepository.aggregateForTripStats(prevFrom, prevTo, stationId, partnerId);
        Long previousTotalBookings = null;
        Double previousTotalRevenue = null;
        Double bookingsDeltaPercent = null;
        Double revenueDeltaPercent = null;
        if (prevAgg != null && (prevAgg.getTotalBookings() > 0 || prevAgg.getTotalRevenue() > 0.5)) {
            previousTotalBookings = prevAgg.getTotalBookings();
            previousTotalRevenue = prevAgg.getTotalRevenue();
            if (previousTotalBookings > 0) {
                bookingsDeltaPercent = ((totalBook - previousTotalBookings) / (double) previousTotalBookings) * 100.0;
            }
            if (previousTotalRevenue > 0.5) {
                revenueDeltaPercent = ((totalRev - previousTotalRevenue) / previousTotalRevenue) * 100.0;
            }
        }

        List<TripStatsPerTripJpa> byCount = bookingRepository.findTripStatsOrderedByBookingCount(
                from, to, stationId, partnerId);
        List<TripStatsPerTripJpa> byRev = bookingRepository.findTripStatsOrderedByRevenue(
                from, to, stationId, partnerId);

        List<Object[]> dailyRaw = bookingRepository.dailyTripStatsBetween(from, to, stationId, partnerId);
        List<TripStatsDayEntryResponse> timeline = buildTimeline(dailyRaw);

        // Ce que la plateforme retient : forfait client (jamais reversé) + commission prélevée
        // sur les ventes — même distinction que la page Transactions admin (Frais Mobili /
        // Commission / Net compagnies), ici agrégée sur toute la période/le périmètre choisi.
        double totalServiceFee = agg.getTotalServiceFee();
        Long commissionRaw = bookingRepository.sumCommissionForPeriod(from, to, stationId, partnerId);
        double totalCommission = commissionRaw != null ? commissionRaw : 0.0;
        double netCompany = totalRev - totalServiceFee - totalCommission;

        return new AdminTripStatsResponse(
                period,
                from,
                to,
                totalBook,
                totalRev,
                distinctTrips,
                avg,
                agg.getRevenueOnline(),
                agg.getRevenueOffline(),
                totalServiceFee,
                totalCommission,
                netCompany,
                previousTotalBookings,
                previousTotalRevenue,
                bookingsDeltaPercent,
                revenueDeltaPercent,
                mapTopN(byCount),
                mapTopN(byRev),
                buildRevenueDonut(byRev, totalRev),
                buildVolumeDonut(byCount, totalBook),
                timeline);
    }

    /**
     * Convertit les lignes brutes (day, count, revenue) en points de courbe — un point par jour
     * civil tel que renvoyé par la requête (les jours sans vente n'apparaissent pas en base,
     * mais rien n'oblige à les combler ici : un simple point manquant sur la courbe suffit,
     * jamais un 0 qui suggérerait à tort une activité mesurée ce jour-là).
     */
    private static List<TripStatsDayEntryResponse> buildTimeline(List<Object[]> rows) {
        List<TripStatsDayEntryResponse> out = new ArrayList<>();
        for (Object[] row : rows) {
            LocalDate date;
            Object rawDate = row[0];
            if (rawDate instanceof java.sql.Date sqlDate) {
                date = sqlDate.toLocalDate();
            } else if (rawDate instanceof LocalDate ld) {
                date = ld;
            } else {
                date = LocalDate.parse(rawDate.toString());
            }
            long count = ((Number) row[1]).longValue();
            double revenue = ((Number) row[2]).doubleValue();
            out.add(new TripStatsDayEntryResponse(date, count, revenue));
        }
        return out;
    }

    private static List<TripStatEntryResponse> mapTopN(List<TripStatsPerTripJpa> rows) {
        List<TripStatEntryResponse> out = new ArrayList<>();
        int rank = 1;
        for (TripStatsPerTripJpa r : rows) {
            if (rank > TOP_N) {
                break;
            }
            String dep = r.getDepartureCity();
            String arr = r.getArrivalCity();
            String partner = r.getPartnerName();
            long cnt = r.getBookingCount();
            double rev = r.getRevenue();
            long tripId = r.getTripId();
            String route = dep + " → " + arr;
            out.add(new TripStatEntryResponse(rank, tripId, route, partner, r.getStationName(), cnt, rev));
            rank++;
        }
        return out;
    }

    private static List<RevenueDonutSliceResponse> buildRevenueDonut(
            List<TripStatsPerTripJpa> byRevOrder, double totalRevenue) {
        if (totalRevenue <= 0.5 || byRevOrder.isEmpty()) {
            return List.of();
        }
        List<RevenueDonutSliceResponse> out = new ArrayList<>();
        double used = 0.0;
        for (int i = 0; i < Math.min(5, byRevOrder.size()); i++) {
            TripStatsPerTripJpa r = byRevOrder.get(i);
            String label = r.getDepartureCity() + " → " + r.getArrivalCity();
            double rev = r.getRevenue();
            used += rev;
            out.add(new RevenueDonutSliceResponse(label, rev, (rev / totalRevenue) * 100.0));
        }
        double rest = totalRevenue - used;
        if (rest > 0.5) {
            out.add(new RevenueDonutSliceResponse("Autres trajets (hors top 5)", rest, (rest / totalRevenue) * 100.0));
        }
        return out;
    }

    private static List<VolumeDonutSliceResponse> buildVolumeDonut(
            List<TripStatsPerTripJpa> byCountOrder, long totalBookings) {
        if (totalBookings < 1 || byCountOrder.isEmpty()) {
            return List.of();
        }
        List<VolumeDonutSliceResponse> out = new ArrayList<>();
        long used = 0L;
        for (int i = 0; i < Math.min(5, byCountOrder.size()); i++) {
            TripStatsPerTripJpa r = byCountOrder.get(i);
            String label = r.getDepartureCity() + " → " + r.getArrivalCity();
            long cnt = r.getBookingCount();
            used += cnt;
            out.add(new VolumeDonutSliceResponse(label, cnt, (cnt / (double) totalBookings) * 100.0));
        }
        long rest = totalBookings - used;
        if (rest > 0) {
            out.add(new VolumeDonutSliceResponse("Autres trajets (hors top 5)", rest,
                    (rest / (double) totalBookings) * 100.0));
        }
        return out;
    }
}
