package com.mobili.backend.module.booking.booking.util;

import java.util.ArrayList;
import java.util.List;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.trip.entity.Trip;

/**
 * Résout le tronçon réellement réservé (Booking.boardingStopIndex/alightingStopIndex), par
 * opposition au trajet complet du voyage (trip.departureCity → trip.arrivalCity). Pendant de
 * TicketSegmentUtil (module ticket) côté Booking — tous les tickets d'une même réservation
 * héritent du même tronçon au moment de la création (voir TicketService : le ticket copie
 * booking.getBoardingStopIndex()/getAlightingStopIndex()), donc Booking est bien la source de
 * vérité ici, pas besoin d'agréger ses tickets.
 */
public final class BookingSegmentUtil {

    private BookingSegmentUtil() {
    }

    /** "Ville embarquement → Ville débarquement" pour CETTE réservation (tronçon réel, pas le trajet complet). */
    public static String resolveRouteLabel(Booking booking) {
        String[] cities = resolveBoardingAlightingCities(booking);
        return cities[0] + " → " + cities[1];
    }

    /** [villeEmbarquement, villeDébarquement] pour cette réservation. */
    public static String[] resolveBoardingAlightingCities(Booking booking) {
        Trip trip = booking.getTrip();
        if (trip == null) {
            return new String[] { "—", "—" };
        }

        List<String> labels = new ArrayList<>();
        String dep = trimCity(trip.getDepartureCity());
        if (!dep.isEmpty()) {
            labels.add(dep);
        }
        if (trip.getMoreInfo() != null && !trip.getMoreInfo().isBlank()) {
            for (String part : trip.getMoreInfo().split(",")) {
                String t = trimCity(part);
                if (!t.isEmpty() && (labels.isEmpty() || !labels.get(labels.size() - 1).equalsIgnoreCase(t))) {
                    labels.add(t);
                }
            }
        }
        String arr = trimCity(trip.getArrivalCity());
        if (!arr.isEmpty() && (labels.isEmpty() || !labels.get(labels.size() - 1).equalsIgnoreCase(arr))) {
            labels.add(arr);
        }

        if (labels.isEmpty()) {
            return new String[] { "—", "—" };
        }

        int last = Math.max(0, labels.size() - 1);
        int boarding = booking.getBoardingStopIndex() != null ? booking.getBoardingStopIndex() : 0;
        int alighting = booking.getAlightingStopIndex() != null ? booking.getAlightingStopIndex() : last;

        String boardingCity = (boarding >= 0 && boarding < labels.size()) ? labels.get(boarding) : labels.get(0);
        String alightingCity = (alighting >= 0 && alighting < labels.size()) ? labels.get(alighting)
                : labels.get(last);

        return new String[] { boardingCity, alightingCity };
    }

    private static String trimCity(String raw) {
        if (raw == null) {
            return "";
        }
        String t = raw.trim();
        if (t.isEmpty()) {
            return "";
        }
        return Character.toUpperCase(t.charAt(0)) + t.substring(1).toLowerCase();
    }
}
