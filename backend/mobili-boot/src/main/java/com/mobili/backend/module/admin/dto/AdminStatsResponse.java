package com.mobili.backend.module.admin.dto;

public record AdminStatsResponse(
        long totalUsers,
        long totalPartners,
        long totalTrips,
        long activeBookings,
        double totalRevenue) {
}