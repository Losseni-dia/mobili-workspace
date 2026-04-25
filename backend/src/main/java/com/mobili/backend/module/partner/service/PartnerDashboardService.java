package com.mobili.backend.module.partner.service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.trip.repository.TripRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class PartnerDashboardService {
    private final BookingRepository bookingRepository;
    private final TripRepository tripRepository;

    /**
     * @param stationId filtre optionnel (dirigeant) : stats (voyages, résa, CA) pour une gare
     */
    public Map<String, Object> getDashboardData(Long partnerId, Long stationId) {
        List<Booking> bookings;
        long tripsCount;
        if (stationId != null) {
            tripsCount = tripRepository.countTripsByPartnerAndStation(partnerId, stationId);
            bookings = bookingRepository.findRecentBookingsByPartnerAndStation(partnerId, stationId);
        } else {
            tripsCount = tripRepository.countTripsByPartner(partnerId);
            bookings = bookingRepository.findRecentBookingsByPartner(partnerId);
        }

        double revenue = 0;
        if (bookings != null) {
            revenue = bookings.stream()
                    .filter(b -> b.getStatus() != null && b.getStatus() == BookingStatus.CONFIRMED)
                    .mapToDouble(Booking::getTotalPrice)
                    .sum();
        }

        Map<String, Object> data = new HashMap<>();
        data.put("activeTrips", tripsCount);
        data.put("totalBookings", bookings != null ? (long) bookings.size() : 0L);
        data.put("totalRevenue", revenue);
        data.put("bookingsList", bookings != null ? bookings : new ArrayList<>());

        return data;
    }
}