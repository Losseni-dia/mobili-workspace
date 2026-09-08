package com.mobili.backend.module.trip.service;

import com.mobili.backend.module.routing.dto.DirectionsRequest;
import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.enums.DirectionsProvider;
import com.mobili.backend.module.routing.service.DirectionsOrchestratorService;
import com.mobili.backend.module.trip.dto.TripEtaResponse;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStatus;
import com.mobili.backend.module.trip.entity.TripStop;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TripEtaServiceTest {

    @Mock
    private TripService tripService;
    @Mock
    private TripRunService tripRunService;
    @Mock
    private DirectionsOrchestratorService directionsOrchestratorService;

    private TripEtaService tripEtaService;

    @BeforeEach
    void setUp() {
        tripEtaService = new TripEtaService(tripService, tripRunService, directionsOrchestratorService);
    }

    private Trip enCoursTrip() {
        Trip trip = new Trip();
        trip.setId(1L);
        trip.setStatus(TripStatus.EN_COURS);
        return trip;
    }

    @Test
    void getEta_tripNotInProgress_throwsValidationError() {
        Trip trip = new Trip();
        trip.setId(1L);
        trip.setStatus(TripStatus.PROGRAMMÉ);
        when(tripService.findById(1L)).thenReturn(trip);

        assertThrows(MobiliException.class, () -> tripEtaService.getEta(1L, 5.35, -4.02));
    }

    @Test
    void getEta_nextStopHasNoCoordinates_returnsUnavailable() {
        Trip trip = enCoursTrip();
        when(tripService.findById(1L)).thenReturn(trip);
        TripStop stop = new TripStop();
        stop.setCityLabel("San-Pedro");
        stop.setLatitude(null);
        stop.setLongitude(null);
        when(tripRunService.nextStopOrNull(trip)).thenReturn(stop);

        TripEtaResponse response = tripEtaService.getEta(1L, 5.35, -4.02);

        assertFalse(response.available());
        assertEquals("San-Pedro", response.destinationCity());
    }

    @Test
    void getEta_noNextStop_returnsUnavailableWithNullDestination() {
        Trip trip = enCoursTrip();
        when(tripService.findById(1L)).thenReturn(trip);
        when(tripRunService.nextStopOrNull(trip)).thenReturn(null);

        TripEtaResponse response = tripEtaService.getEta(1L, 5.35, -4.02);

        assertFalse(response.available());
        assertEquals(null, response.destinationCity());
    }

    @Test
    void getEta_nextStopHasCoordinates_callsOrchestratorAndReturnsAvailable() {
        Trip trip = enCoursTrip();
        when(tripService.findById(1L)).thenReturn(trip);
        TripStop stop = new TripStop();
        stop.setCityLabel("San-Pedro");
        stop.setLatitude(4.7485);
        stop.setLongitude(-6.6363);
        when(tripRunService.nextStopOrNull(trip)).thenReturn(stop);
        DirectionsResult result = new DirectionsResult(600L, 8000.0, DirectionsProvider.MAPBOX);
        when(directionsOrchestratorService.getDirectionsWithFallback(any())).thenReturn(result);

        TripEtaResponse response = tripEtaService.getEta(1L, 5.35, -4.02);

        assertTrue(response.available());
        assertEquals("San-Pedro", response.destinationCity());
        assertEquals(600L, response.durationSeconds());
        assertEquals("MAPBOX", response.provider());
        verify(directionsOrchestratorService).getDirectionsWithFallback(
                new DirectionsRequest(5.35, -4.02, 4.7485, -6.6363));
    }

    @Test
    void getEta_orchestratorThrows_returnsUnavailableInsteadOfPropagating() {
        // Ni Mapbox ni Google Maps n'ont pu calculer d'itinéraire (ex. position d'origine trop
        // éloignée pour un trajet routier, ou panne réseau des deux fournisseurs) — voir
        // TripEtaService.getEta, qui doit dégrader vers "indisponible" plutôt que de laisser
        // l'exception remonter en 500.
        Trip trip = enCoursTrip();
        when(tripService.findById(1L)).thenReturn(trip);
        TripStop stop = new TripStop();
        stop.setCityLabel("San-Pedro");
        stop.setLatitude(4.7485);
        stop.setLongitude(-6.6363);
        when(tripRunService.nextStopOrNull(trip)).thenReturn(stop);
        when(directionsOrchestratorService.getDirectionsWithFallback(any()))
                .thenThrow(new RuntimeException("Aucun itinéraire trouvé par aucun fournisseur"));

        TripEtaResponse response = tripEtaService.getEta(1L, 50.85, 4.35);

        assertFalse(response.available());
        assertEquals("San-Pedro", response.destinationCity());
    }

    @Test
    void getEta_secondCallWithinTtl_usesCacheWithoutCallingOrchestratorAgain() {
        Trip trip = enCoursTrip();
        when(tripService.findById(1L)).thenReturn(trip);
        TripStop stop = new TripStop();
        stop.setCityLabel("San-Pedro");
        stop.setLatitude(4.7485);
        stop.setLongitude(-6.6363);
        when(tripRunService.nextStopOrNull(trip)).thenReturn(stop);
        when(directionsOrchestratorService.getDirectionsWithFallback(any()))
                .thenReturn(new DirectionsResult(600L, 8000.0, DirectionsProvider.MAPBOX));

        tripEtaService.getEta(1L, 5.35, -4.02);
        tripEtaService.getEta(1L, 5.35, -4.02);

        verify(directionsOrchestratorService, times(1)).getDirectionsWithFallback(any());
    }
}
