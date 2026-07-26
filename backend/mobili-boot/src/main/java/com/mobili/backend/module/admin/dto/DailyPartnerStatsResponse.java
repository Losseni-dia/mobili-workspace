package com.mobili.backend.module.admin.dto;

import java.time.LocalDate;
import java.util.List;

public record DailyPartnerStatsResponse(
        long todayRegistrations,
        long totalPartners,
        List<DayEntry> history) {

    public record DayEntry(LocalDate date, long count) {
    }
}