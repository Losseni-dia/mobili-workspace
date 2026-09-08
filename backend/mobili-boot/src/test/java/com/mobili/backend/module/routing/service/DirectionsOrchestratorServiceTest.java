package com.mobili.backend.module.routing.service;

import com.mobili.backend.module.routing.dto.DirectionsRequest;
import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.enums.DirectionsProvider;
import com.mobili.backend.module.routing.exception.NoRouteFoundException;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.client.RestClientException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Couvre la seule logique de bascule du module routing — le resolver est mocké directement
 * (jamais de RestClient réel ici), pour isoler purement le comportement de décision.
 */
@ExtendWith(MockitoExtension.class)
class DirectionsOrchestratorServiceTest {

    @Mock
    private DirectionsGatewayResolver resolver;
    @Mock
    private DirectionsProviderService mapboxService;
    @Mock
    private DirectionsProviderService googleMapsService;

    private DirectionsOrchestratorService orchestrator;
    private final DirectionsRequest request = new DirectionsRequest(5.35, -4.02, 5.36, -4.03);

    @BeforeEach
    void setUp() {
        orchestrator = new DirectionsOrchestratorService(resolver);
    }

    @Test
    void getDirectionsWithFallback_mapboxSucceeds_returnsMapboxResultWithoutCallingGoogleMaps() {
        when(resolver.resolve(DirectionsProvider.MAPBOX)).thenReturn(mapboxService);
        DirectionsResult mapboxResult = new DirectionsResult(600L, 8000.0, DirectionsProvider.MAPBOX);
        when(mapboxService.getDirections(request)).thenReturn(mapboxResult);

        DirectionsResult result = orchestrator.getDirectionsWithFallback(request);

        assertEquals(mapboxResult, result);
        verify(resolver, never()).resolve(DirectionsProvider.GOOGLE_MAPS);
    }

    @Test
    void getDirectionsWithFallback_mapboxNoRoute_fallsBackToGoogleMaps() {
        when(resolver.resolve(DirectionsProvider.MAPBOX)).thenReturn(mapboxService);
        when(mapboxService.getDirections(request)).thenThrow(new NoRouteFoundException("aucun itinéraire"));
        when(resolver.resolve(DirectionsProvider.GOOGLE_MAPS)).thenReturn(googleMapsService);
        DirectionsResult fallbackResult = new DirectionsResult(700L, 9000.0, DirectionsProvider.GOOGLE_MAPS);
        when(googleMapsService.getDirections(request)).thenReturn(fallbackResult);

        DirectionsResult result = orchestrator.getDirectionsWithFallback(request);

        assertEquals(fallbackResult, result);
        assertEquals(DirectionsProvider.GOOGLE_MAPS, result.provider());
    }

    @Test
    void getDirectionsWithFallback_genericNetworkError_propagatesWithoutFallback() {
        when(resolver.resolve(DirectionsProvider.MAPBOX)).thenReturn(mapboxService);
        when(mapboxService.getDirections(request)).thenThrow(new RestClientException("timeout"));

        assertThrows(RestClientException.class, () -> orchestrator.getDirectionsWithFallback(request));
        verify(resolver, never()).resolve(DirectionsProvider.GOOGLE_MAPS);
        verify(googleMapsService, never()).getDirections(any());
    }
}
