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

    /** Un arrêt déjà résolu (ville + coordonnées si connues) — voir TripService.buildStructuredStops. */
    public record ResolvedStop(String cityLabel, Double latitude, Double longitude) {
    }

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

    /**
     * Même reconstruction que {@link #syncStopsForTrip(Trip)}, mais à partir d'arrêts déjà résolus
     * vers de vraies villes (cityId/coordonnées connues) au lieu de redécouper
     * {@code trip.getMoreInfo()} sur des virgules — utilisé quand le client envoie
     * {@code TripRequestDTO.stops}/{@code departureCityId}/{@code arrivalCityId} (voir
     * TripService.save). Les coordonnées, quand présentes, alimentent le calcul de durée réelle
     * (module routing) au lieu du forfait {@link #PLANNED_LEG_MINUTES} par tronçon.
     */
    public void syncStopsForTrip(Trip trip, List<ResolvedStop> resolvedStops) {
        trip.getStops().clear();
        LocalDateTime base = trip.getDepartureDateTime();
        for (int i = 0; i < resolvedStops.size(); i++) {
            ResolvedStop r = resolvedStops.get(i);
            TripStop stop = new TripStop();
            stop.setTrip(trip);
            stop.setStopIndex(i);
            stop.setCityLabel(r.cityLabel());
            stop.setLatitude(r.latitude());
            stop.setLongitude(r.longitude());
            // TODO(B3) : remplacer par la durée réelle (DirectionsOrchestratorService) quand les
            // coordonnées des deux extrémités du tronçon sont connues ; repli sur ce forfait sinon.
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
