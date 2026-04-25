package com.mobili.backend.module.admin.dto;

import java.time.LocalDate;
import java.util.List;

public record DailyLoginStatsResponse(
        long todayTotalLogins,
        long todayUniqueUsers,
        List<DayEntry> history) {

    public record DayEntry(
            LocalDate date,
            long totalLogins,
            long uniqueUsers) {
    }
}
