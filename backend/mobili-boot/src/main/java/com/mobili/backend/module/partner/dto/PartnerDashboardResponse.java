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
    private double revenueOnline;
    private double revenueOffline;
    /** Tickets vendus (actifs, hors ANNULÉ) depuis toujours, par canal — voir PartnerDashboardService. */
    private long ticketsSoldOnline;
    private long ticketsSoldOffline;
    private List<RecentBookingDTO> recentBookings;
}