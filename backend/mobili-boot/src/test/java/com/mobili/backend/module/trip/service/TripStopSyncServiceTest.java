package com.mobili.backend.module.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.enums.DirectionsProvider;
import com.mobili.backend.module.routing.exception.NoRouteFoundException;
import com.mobili.backend.module.routing.service.DirectionsOrchestratorService;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStop;

/**
 * Couvre le nouvel overload {@code syncStopsForTrip(Trip, List<ResolvedStop>)} (chantiers B1/B3,
 * arrêts structurés + durée réelle) — l'overload historique texte (moreInfo CSV) reste inchangé,
 * déjà couvert indirectement par TripServiceSearchTest, et n'appelle jamais le module routing.
 */
@ExtendWith(MockitoExtension.class)
class TripStopSyncServiceTest {

    @Mock
    private DirectionsOrchestratorService directionsOrchestratorService;

    private TripStopSyncService service;

    @BeforeEach
    void setUp() {
        service = new TripStopSyncService(directionsOrchestratorService);
    }

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
        // Tronçon Abidjan -> Yamoussoukro : coordonnées connues des deux côtés, durée réelle
        // utilisée (90 min ici) au lieu du forfait de 60 min.
        when(directionsOrchestratorService.getDirectionsWithFallback(any()))
                .thenReturn(new DirectionsResult(90 * 60L, 210_000, DirectionsProvider.MAPBOX));

        service.syncStopsForTrip(trip, resolved);

        List<TripStop> stops = trip.getStops();
        assertEquals(3, stops.size());
        assertEquals("Abidjan", stops.get(0).getCityLabel());
        assertEquals(5.31, stops.get(0).getLatitude());
        assertEquals(-4.03, stops.get(0).getLongitude());
        assertEquals(0, stops.get(0).getStopIndex());
        assertEquals(trip.getDepartureDateTime(), stops.get(0).getPlannedDepartureAt());

        assertEquals("Yamoussoukro", stops.get(1).getCityLabel());
        assertEquals(1, stops.get(1).getStopIndex());
        // Durée réelle (90 min), pas le forfait de 60 min.
        assertEquals(trip.getDepartureDateTime().plusMinutes(90), stops.get(1).getPlannedDepartureAt());

        assertEquals("Bouaké", stops.get(2).getCityLabel());
        // Ville pas encore géocodée (créée en attente de validation admin) : coordonnées nulles,
        // jamais bloquant — repli sur le forfait de 60 min pour CE tronçon uniquement (voir B3),
        // jamais un appel au module routing pour un tronçon incomplet.
        assertNull(stops.get(2).getLatitude());
        assertNull(stops.get(2).getLongitude());
        assertEquals(trip.getDepartureDateTime().plusMinutes(90 + 60), stops.get(2).getPlannedDepartureAt());
    }

    @Test
    void syncStopsForTrip_resolvedStops_fallsBackToForfaitOnDirectionsFailure() {
        Trip trip = trip();
        List<TripStopSyncService.ResolvedStop> resolved = List.of(
                new TripStopSyncService.ResolvedStop("Abidjan", 5.31, -4.03),
                new TripStopSyncService.ResolvedStop("San-Pédro", 4.75, -6.64));
        // Ni Mapbox ni Google Maps n'ont pu calculer d'itinéraire — dégrade vers le forfait,
        // jamais une exception qui casserait la création/modification du trajet.
        when(directionsOrchestratorService.getDirectionsWithFallback(any()))
                .thenThrow(new NoRouteFoundException("aucun itinéraire"));

        service.syncStopsForTrip(trip, resolved);

        assertEquals(
                trip.getDepartureDateTime().plusMinutes(TripStopSyncService.PLANNED_LEG_MINUTES),
                trip.getStops().get(1).getPlannedDepartureAt());
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
        // Chemin texte historique : jamais de coordonnées, donc jamais d'appel au module routing
        // (coûteux) — seul l'overload résolu (B3) en déclenche.
        verifyNoInteractions(directionsOrchestratorService);
    }
}
