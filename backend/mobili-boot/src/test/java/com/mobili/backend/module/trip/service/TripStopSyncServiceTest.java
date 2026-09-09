package com.mobili.backend.module.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStop;

/**
 * Couvre le nouvel overload {@code syncStopsForTrip(Trip, List<ResolvedStop>)} (chantier B1,
 * arrêts structurés) — l'overload historique texte (moreInfo CSV) reste inchangé, déjà couvert
 * indirectement par TripServiceSearchTest.
 */
class TripStopSyncServiceTest {

    private final TripStopSyncService service = new TripStopSyncService();

    private Trip trip() {
        Trip trip = new Trip();
        trip.setDepartureDateTime(LocalDateTime.of(2030, 6, 1, 8, 0));
        trip.setStops(new ArrayList<>());
        return trip;
    }

    @Test
    void syncStopsForTrip_resolvedStops_usesGivenLabelsAndCoordinates() {
        Trip trip = trip();
        List<TripStopSyncService.ResolvedStop> resolved = List.of(
                new TripStopSyncService.ResolvedStop("Abidjan", 5.31, -4.03),
                new TripStopSyncService.ResolvedStop("Yamoussoukro", 6.82, -5.28),
                new TripStopSyncService.ResolvedStop("Bouaké", null, null));

        service.syncStopsForTrip(trip, resolved);

        List<TripStop> stops = trip.getStops();
        assertEquals(3, stops.size());
        assertEquals("Abidjan", stops.get(0).getCityLabel());
        assertEquals(5.31, stops.get(0).getLatitude());
        assertEquals(-4.03, stops.get(0).getLongitude());
        assertEquals(0, stops.get(0).getStopIndex());
        assertEquals("Yamoussoukro", stops.get(1).getCityLabel());
        assertEquals(1, stops.get(1).getStopIndex());
        assertEquals("Bouaké", stops.get(2).getCityLabel());
        // Ville pas encore géocodée (créée en attente de validation admin) : coordonnées nulles,
        // jamais bloquant — repli sur le forfait horaire pour ce tronçon (voir B3).
        assertNull(stops.get(2).getLatitude());
        assertNull(stops.get(2).getLongitude());
    }

    @Test
    void syncStopsForTrip_resolvedStops_clearsPreviousStops() {
        Trip trip = trip();
        trip.getStops().add(new TripStop());

        service.syncStopsForTrip(trip, List.of(new TripStopSyncService.ResolvedStop("Abidjan", null, null)));

        assertEquals(1, trip.getStops().size());
    }

    @Test
    void syncStopsForTrip_legacyTextPath_stillWorksUnchanged() {
        Trip trip = trip();
        trip.setDepartureCity("Abidjan");
        trip.setArrivalCity("Bouaké");
        trip.setMoreInfo("Yamoussoukro");

        service.syncStopsForTrip(trip);

        List<TripStop> stops = trip.getStops();
        assertEquals(3, stops.size());
        assertEquals("Abidjan", stops.get(0).getCityLabel());
        assertEquals("Yamoussoukro", stops.get(1).getCityLabel());
        assertEquals("Bouaké", stops.get(2).getCityLabel());
        assertNull(stops.get(0).getLatitude());
    }
}
