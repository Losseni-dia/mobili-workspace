package com.mobili.backend.module.admin.dto;

import java.time.LocalDate;
import java.util.List;

public record DailyTicketStatsResponse(
        long todayTickets,
        long totalTickets,
        List<DayEntry> history) {

    public record DayEntry(LocalDate date, long count) {
    }
}