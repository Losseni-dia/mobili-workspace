package com.mobili.backend.module.admin.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.mobili.backend.module.admin.model.TripStatsPeriod;

/**
 * Tableau de bord trajets (top 10, KPI, parts pour donut).
 */
public record AdminTripStatsResponse(
        TripStatsPeriod period,
        LocalDateTime fromInclusive,
        LocalDateTime toExclusive,
        long totalBookings,
        double totalRevenueFcfa,
        long activeTripCount,
        double avgRevenuePerBooking,
        List<TripStatEntryResponse> top10ByBookings,
        List<TripStatEntryResponse> top10ByRevenue,
        List<RevenueDonutSliceResponse> revenueByTripDonut,
        List<VolumeDonutSliceResponse> volumeByTripDonut) {
}
