package com.mobili.backend.module.admin.service;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

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
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class TripStatisticsService {

    private final BookingRepository bookingRepository;
    private final TicketRepository ticketRepository;

    /** Nombre de lignes renvoyées par classement — la page affiche un "top 10" par défaut avec
     *  "Voir plus" côté client jusqu'à cette limite, sans nouvel appel réseau. */
    private static final int TOP_N = 50;

    /**
     * Ligne trajet fusionnée : métadonnées + CA (BookingRepository.findTripStatsOrderedByRevenue,
     * inchangé) + nombre de tickets (TicketRepository.ticketCountsPerTripForPeriod, requête
     * séparée). Ne JAMAIS combiner COUNT(ticket) et SUM(booking.totalPrice) dans une même requête
     * groupée : un ticket-join dupliquerait le CA de chaque réservation multi-sièges (Cartesian
     * product, cf. BookingRepository.findByIdWithDetailsRaw pour le même risque déjà documenté).
     */
    private record TripRow(
            long tripId,
            String departureCity,
            String arrivalCity,
            String partnerName,
            String stationName,
            double revenue,
            long ticketCount) {
    }

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
        long distinctTrips = agg.getDistinctTrips();

        // "Billets" = tickets actifs (unité = un siège vendu), jamais des réservations — voir
        // TicketRepository.countActiveTicketsForPeriod pour la justification (écart constaté en
        // prod entre "Tickets vendus" du dashboard admin et l'ancien COUNT(booking) ici).
        Long totalTicketsRaw = ticketRepository.countActiveTicketsForPeriod(from, to, stationId, partnerId);
        long totalTickets = totalTicketsRaw != null ? totalTicketsRaw : 0L;
        double avg = totalTickets > 0 ? totalRev / (double) totalTickets : 0.0;

        // Période précédente de même durée, immédiatement avant `from` — pour une variation en
        // % ("+12 % vs période précédente"), jamais affichée si la précédente est vide (évite
        // une div/0 ou un pourcentage absurde du type "+∞ %").
        long durationSeconds = Duration.between(from, to).getSeconds();
        LocalDateTime prevTo = from;
        LocalDateTime prevFrom = from.minusSeconds(durationSeconds);
        TripStatsAggrJpa prevAgg = bookingRepository.aggregateForTripStats(prevFrom, prevTo, stationId, partnerId);
        Long prevTicketsRaw = ticketRepository.countActiveTicketsForPeriod(prevFrom, prevTo, stationId, partnerId);
        Long previousTotalTickets = null;
        Double previousTotalRevenue = null;
        Double ticketsDeltaPercent = null;
        Double revenueDeltaPercent = null;
        long prevTickets = prevTicketsRaw != null ? prevTicketsRaw : 0L;
        if (prevAgg != null && (prevTickets > 0 || prevAgg.getTotalRevenue() > 0.5)) {
            previousTotalTickets = prevTickets;
            previousTotalRevenue = prevAgg.getTotalRevenue();
            if (previousTotalTickets > 0) {
                ticketsDeltaPercent = ((totalTickets - previousTotalTickets) / (double) previousTotalTickets) * 100.0;
            }
            if (previousTotalRevenue > 0.5) {
                revenueDeltaPercent = ((totalRev - previousTotalRevenue) / previousTotalRevenue) * 100.0;
            }
        }

        List<TripStatsPerTripJpa> byRevOrder = bookingRepository.findTripStatsOrderedByRevenue(
                from, to, stationId, partnerId);
        List<Object[]> ticketCountRows = ticketRepository.ticketCountsPerTripForPeriod(
                from, to, stationId, partnerId);
        Map<Long, Long> ticketCountByTrip = new HashMap<>();
        for (Object[] row : ticketCountRows) {
            Long tripId = ((Number) row[0]).longValue();
            long cnt = ((Number) row[1]).longValue();
            ticketCountByTrip.put(tripId, cnt);
        }

        List<TripRow> rows = new ArrayList<>();
        for (TripStatsPerTripJpa r : byRevOrder) {
            rows.add(new TripRow(
                    r.getTripId(),
                    r.getDepartureCity(),
                    r.getArrivalCity(),
                    r.getPartnerName(),
                    r.getStationName(),
                    r.getRevenue(),
                    ticketCountByTrip.getOrDefault(r.getTripId(), 0L)));
        }

        // byRevOrder est déjà trié par CA décroissant (requête SQL) — conservé tel quel.
        List<TripRow> byRevenue = rows;
        // Tri par nombre de billets décroissant, calculé ici en Java (jamais en SQL sur un COUNT
        // de ticket combiné à un SUM de booking, pour la raison Cartesian product documentée
        // plus haut) — égalité départagée par tripId croissant, comme les requêtes SQL d'origine.
        List<TripRow> byTickets = new ArrayList<>(rows);
        byTickets.sort(Comparator.comparingLong(TripRow::ticketCount).reversed()
                .thenComparingLong(TripRow::tripId));

        List<Object[]> dailyRevenueRaw = bookingRepository.dailyTripStatsBetween(from, to, stationId, partnerId);
        List<Object[]> dailyTicketsRaw = ticketRepository.dailyActiveTicketsBetweenForTripStats(
                from, to, stationId, partnerId);
        List<TripStatsDayEntryResponse> timeline = buildTimeline(dailyRevenueRaw, dailyTicketsRaw);

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
                totalTickets,
                totalRev,
                distinctTrips,
                avg,
                agg.getRevenueOnline(),
                agg.getRevenueOffline(),
                totalServiceFee,
                totalCommission,
                netCompany,
                previousTotalTickets,
                previousTotalRevenue,
                ticketsDeltaPercent,
                revenueDeltaPercent,
                mapTopN(byTickets),
                mapTopN(byRevenue),
                buildRevenueDonut(byRevenue, totalRev),
                buildVolumeDonut(byTickets, totalTickets),
                timeline);
    }

    /**
     * Fusionne les deux séries journalières (CA depuis les réservations, billets depuis les
     * tickets) par date — un jour peut apparaître dans l'une sans l'autre en théorie (aucune
     * raison métier connue, mais défensif) : dans ce cas la métrique manquante vaut 0 pour ce
     * jour plutôt que d'exclure le point entier.
     */
    private static List<TripStatsDayEntryResponse> buildTimeline(
            List<Object[]> revenueRows, List<Object[]> ticketRows) {
        Map<LocalDate, Double> revenueByDate = new HashMap<>();
        for (Object[] row : revenueRows) {
            LocalDate date = parseDate(row[0]);
            double revenue = ((Number) row[2]).doubleValue();
            revenueByDate.put(date, revenue);
        }
        Map<LocalDate, Long> ticketsByDate = new HashMap<>();
        for (Object[] row : ticketRows) {
            LocalDate date = parseDate(row[0]);
            long cnt = ((Number) row[1]).longValue();
            ticketsByDate.put(date, cnt);
        }
        java.util.TreeSet<LocalDate> allDates = new java.util.TreeSet<>();
        allDates.addAll(revenueByDate.keySet());
        allDates.addAll(ticketsByDate.keySet());

        List<TripStatsDayEntryResponse> out = new ArrayList<>();
        for (LocalDate date : allDates) {
            long tickets = ticketsByDate.getOrDefault(date, 0L);
            double revenue = revenueByDate.getOrDefault(date, 0.0);
            out.add(new TripStatsDayEntryResponse(date, tickets, revenue));
        }
        return out;
    }

    private static LocalDate parseDate(Object rawDate) {
        if (rawDate instanceof java.sql.Date sqlDate) {
            return sqlDate.toLocalDate();
        } else if (rawDate instanceof LocalDate ld) {
            return ld;
        }
        return LocalDate.parse(rawDate.toString());
    }

    private static List<TripStatEntryResponse> mapTopN(List<TripRow> rows) {
        List<TripStatEntryResponse> out = new ArrayList<>();
        int rank = 1;
        for (TripRow r : rows) {
            if (rank > TOP_N) {
                break;
            }
            String route = r.departureCity() + " → " + r.arrivalCity();
            out.add(new TripStatEntryResponse(
                    rank, r.tripId(), route, r.partnerName(), r.stationName(), r.ticketCount(), r.revenue()));
            rank++;
        }
        return out;
    }

    private static List<RevenueDonutSliceResponse> buildRevenueDonut(
            List<TripRow> byRevOrder, double totalRevenue) {
        if (totalRevenue <= 0.5 || byRevOrder.isEmpty()) {
            return List.of();
        }
        List<RevenueDonutSliceResponse> out = new ArrayList<>();
        double used = 0.0;
        for (int i = 0; i < Math.min(5, byRevOrder.size()); i++) {
            TripRow r = byRevOrder.get(i);
            String label = r.departureCity() + " → " + r.arrivalCity();
            double rev = r.revenue();
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
            List<TripRow> byTicketsOrder, long totalTickets) {
        if (totalTickets < 1 || byTicketsOrder.isEmpty()) {
            return List.of();
        }
        List<VolumeDonutSliceResponse> out = new ArrayList<>();
        long used = 0L;
        for (int i = 0; i < Math.min(5, byTicketsOrder.size()); i++) {
            TripRow r = byTicketsOrder.get(i);
            String label = r.departureCity() + " → " + r.arrivalCity();
            long cnt = r.ticketCount();
            used += cnt;
            out.add(new VolumeDonutSliceResponse(label, cnt, (cnt / (double) totalTickets) * 100.0));
        }
        long rest = totalTickets - used;
        if (rest > 0) {
            out.add(new VolumeDonutSliceResponse("Autres trajets (hors top 5)", rest,
                    (rest / (double) totalTickets) * 100.0));
        }
        return out;
    }
}
