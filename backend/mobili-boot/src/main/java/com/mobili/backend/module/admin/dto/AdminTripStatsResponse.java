package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.mobili.backend.module.admin.model.TripStatsPeriod;

/**
 * Tableau de bord trajets (top N, KPI, parts pour donut, courbe de croissance).
 */
public record AdminTripStatsResponse(
        TripStatsPeriod period,
        LocalDateTime fromInclusive,
        LocalDateTime toExclusive,
        long totalBookings,
        double totalRevenueFcfa,
        long activeTripCount,
        double avgRevenuePerBooking,
        /** Répartition du CA de la période par canal (CONFIRMED/COMPLETED = en ligne,
         *  OFFLINE_SALE = guichet) — même principe que les dashboards partenaire/gare/admin. */
        double revenueOnlineFcfa,
        double revenueOfflineFcfa,
        /** Ce que la plateforme retient sur la période : forfait client (jamais reversé à la
         *  compagnie) + commission prélevée sur les ventes. netCompanyFcfa = ce qui revient
         *  réellement aux compagnies = totalRevenueFcfa - totalServiceFeeFcfa - totalCommissionFcfa. */
        double totalServiceFeeFcfa,
        double totalCommissionFcfa,
        double netCompanyFcfa,
        /** Même agrégats que ci-dessus, mais sur la période précédente de même durée
         *  immédiatement avant `fromInclusive` — sert à calculer une variation en %. Null si la
         *  période précédente n'a aucune donnée (évite une division par zéro côté client). */
        Long previousTotalBookings,
        Double previousTotalRevenueFcfa,
        Double bookingsDeltaPercent,
        Double revenueDeltaPercent,
        List<TripStatEntryResponse> top10ByBookings,
        List<TripStatEntryResponse> top10ByRevenue,
        List<RevenueDonutSliceResponse> revenueByTripDonut,
        List<VolumeDonutSliceResponse> volumeByTripDonut,
        /** Courbe de croissance — un point par jour civil sur la période demandée. */
        List<TripStatsDayEntryResponse> timeline) {
}
