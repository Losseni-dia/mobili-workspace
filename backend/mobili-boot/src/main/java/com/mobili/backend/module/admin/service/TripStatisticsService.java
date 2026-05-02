package com.mobili.backend.module.admin.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.admin.dto.AdminTripStatsResponse;
import com.mobili.backend.module.admin.dto.RevenueDonutSliceResponse;
import com.mobili.backend.module.admin.dto.TripStatEntryResponse;
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

    @Transactional(readOnly = true)
    public AdminTripStatsResponse forPeriod(TripStatsPeriod period) {
        LocalDateTime to = LocalDateTime.now();
        LocalDateTime from = switch (period) {
            case DAY -> LocalDate.now().atStartOfDay();
            case WEEK -> LocalDate.now().minusDays(6).atStartOfDay();
            case MONTH -> LocalDate.now().minusDays(29).atStartOfDay();
        };

        TripStatsAggrJpa agg = bookingRepository.aggregateForTripStats(from, to);
        if (agg == null) {
            agg = new TripStatsAggrJpa(0.0, 0L, 0L);
        }
        double totalRev = agg.getTotalRevenue();
        long totalBook = agg.getTotalBookings();
        long distinctTrips = agg.getDistinctTrips();
        double avg = totalBook > 0 ? totalRev / (double) totalBook : 0.0;

        List<TripStatsPerTripJpa> byCount = bookingRepository.findTripStatsOrderedByBookingCount(from, to);
        List<TripStatsPerTripJpa> byRev = bookingRepository.findTripStatsOrderedByRevenue(from, to);

        return new AdminTripStatsResponse(
                period,
                from,
                to,
                totalBook,
                totalRev,
                distinctTrips,
                avg,
                mapTop10(byCount),
                mapTop10(byRev),
                buildRevenueDonut(byRev, totalRev),
                buildVolumeDonut(byCount, totalBook));
    }

    private static List<TripStatEntryResponse> mapTop10(List<TripStatsPerTripJpa> rows) {
        List<TripStatEntryResponse> out = new ArrayList<>();
        int rank = 1;
        for (TripStatsPerTripJpa r : rows) {
            if (rank > 10) {
                break;
            }
            String dep = r.getDepartureCity();
            String arr = r.getArrivalCity();
            String partner = r.getPartnerName();
            long cnt = r.getBookingCount();
            double rev = r.getRevenue();
            long tripId = r.getTripId();
            String route = dep + " → " + arr;
            out.add(new TripStatEntryResponse(rank, tripId, route, partner, cnt, rev));
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
