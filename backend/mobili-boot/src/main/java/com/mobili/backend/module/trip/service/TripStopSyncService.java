package com.mobili.backend.module.trip.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import org.springframework.stereotype.Service;

import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStop;

import lombok.RequiredArgsConstructor;

/**
 * Reconstruit la liste ordonnée des arrêts (villes) et les horaires planifiés de départ par arrêt.
 * Pas de GPS : cut-off basé sur {@link TripStop#getPlannedDepartureAt()} + événements chauffeur.
 */
@Service
@RequiredArgsConstructor
public class TripStopSyncService {

    /** Délai entre deux arrêts consécutifs pour l’horaire planifié (MVP). */
    public static final int PLANNED_LEG_MINUTES = 60;

    public void syncStopsForTrip(Trip trip) {
        trip.getStops().clear();
        List<String> labels = buildCityLabels(trip);
        LocalDateTime base = trip.getDepartureDateTime();
        for (int i = 0; i < labels.size(); i++) {
            TripStop stop = new TripStop();
            stop.setTrip(trip);
            stop.setStopIndex(i);
            stop.setCityLabel(labels.get(i));
            stop.setPlannedDepartureAt(base.plusMinutes((long) i * PLANNED_LEG_MINUTES));
            trip.getStops().add(stop);
        }
    }

    /** Libellés affichage : départ, étapes CSV, arrivée (sans doublon terminal). */
    public List<String> buildCityLabels(Trip trip) {
        List<String> labels = new ArrayList<>();
        labels.add(trimCity(trip.getDepartureCity()));
        if (trip.getMoreInfo() != null && !trip.getMoreInfo().isBlank()) {
            for (String part : trip.getMoreInfo().split(",")) {
                String t = trimCity(part);
                if (!t.isEmpty() && !labels.get(labels.size() - 1).equalsIgnoreCase(t)) {
                    labels.add(t);
                }
            }
        }
        String arr = trimCity(trip.getArrivalCity());
        if (labels.isEmpty() || !labels.get(labels.size() - 1).equalsIgnoreCase(arr)) {
            labels.add(arr);
        }
        return labels;
    }

    public int lastStopIndex(Trip trip) {
        return Math.max(0, buildCityLabels(trip).size() - 1);
    }

    private static String trimCity(String raw) {
        if (raw == null) {
            return "";
        }
        String t = raw.trim();
        if (t.isEmpty()) {
            return "";
        }
        return t.substring(0, 1).toUpperCase(Locale.ROOT) + t.substring(1).toLowerCase(Locale.ROOT);
    }
}
