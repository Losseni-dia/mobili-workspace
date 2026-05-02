package com.mobili.backend.module.partner.dto;

import lombok.Builder;
import lombok.Data;
import java.util.List;

@Data
@Builder
public class PartnerDashboardResponse {
    private long activeTripsCount;
    private long totalBookingsCount;
    private double totalRevenue;
    private List<RecentBookingDTO> recentBookings;
}