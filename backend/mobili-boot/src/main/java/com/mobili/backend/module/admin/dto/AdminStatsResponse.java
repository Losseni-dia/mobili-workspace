package com.mobili.backend.module.admin.dto;

public record AdminStatsResponse(
        long totalUsers,
        long totalPartners,
        long totalTrips,
        long totalTickets,
        long activeBookings,
        double totalRevenue) {
}