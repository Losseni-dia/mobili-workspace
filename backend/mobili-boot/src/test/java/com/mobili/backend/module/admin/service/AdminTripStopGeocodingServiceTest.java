package com.mobili.backend.module.admin.service;

import com.mobili.backend.module.admin.dto.GeocodingApplyRequest;
import com.mobili.backend.module.admin.dto.GeocodingApplyResponse;
import com.mobili.backend.module.admin.dto.GeocodingPreviewResponse;
import com.mobili.backend.module.routing.exception.GeocodingFailedException;
import com.mobili.backend.module.routing.mapbox.dto.GeocodingResult;
import com.mobili.backend.module.routing.mapbox.service.MapboxGeocodingService;
import com.mobili.backend.module.trip.repository.TripStopRepository;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminTripStopGeocodingServiceTest {

    @Mock
    private TripStopRepository tripStopRepository;
    @Mock
    private MapboxGeocodingService mapboxGeocodingService;

    private AdminTripStopGeocodingService service;

    @BeforeEach
    void setUp() {
        service = new AdminTripStopGeocodingService(tripStopRepository, mapboxGeocodingService);
    }

    @Test
    void preview_realCity_returnsSuccessItem() {
        when(tripStopRepository.findDistinctCityLabelsMissingCoordinates())
                .thenReturn(List.of("Toumodi"));
        when(mapboxGeocodingService.geocode("Toumodi")).thenReturn(new GeocodingResult(6.55, -5.0167));

        GeocodingPreviewResponse response = service.preview();

        assertEquals(1, response.items().size());
        var item = response.items().get(0);
        assertEquals("Toumodi", item.cityLabel());
        assertEquals(6.55, item.latitude());
        assertFalse(item.ambiguous());
        assertNull(item.errorMessage());
    }

    @Test
    void preview_testDataPattern_excludedWithoutCallingMapbox() {
        when(tripStopRepository.findDistinctCityLabelsMissingCoordinates())
                .thenReturn(List.of("Ssss", "Ville desservie 1", "None"));

        GeocodingPreviewResponse response = service.preview();

        assertEquals(3, response.items().size());
        assertTrue(response.items().stream().allMatch(i -> i.latitude() == null));
        org.mockito.Mockito.verifyNoInteractions(mapboxGeocodingService);
    }

    @Test
    void preview_ambiguousName_flagged() {
        when(tripStopRepository.findDistinctCityLabelsMissingCoordinates())
                .thenReturn(List.of("Touba"));
        when(mapboxGeocodingService.geocode("Touba")).thenReturn(new GeocodingResult(14.86, -15.87));

        GeocodingPreviewResponse response = service.preview();

        assertTrue(response.items().get(0).ambiguous());
    }

    @Test
    void preview_mapboxGeocodingFails_returnsFailureItemInsteadOfThrowing() {
        when(tripStopRepository.findDistinctCityLabelsMissingCoordinates())
                .thenReturn(List.of("Pogo"));
        when(mapboxGeocodingService.geocode("Pogo"))
                .thenThrow(new GeocodingFailedException("Aucun résultat"));

        GeocodingPreviewResponse response = service.preview();

        var item = response.items().get(0);
        assertNull(item.latitude());
        assertEquals("Aucun résultat", item.errorMessage());
    }

    @Test
    void apply_validItems_updatesRepositoryAndReturnsCount() {
        GeocodingApplyRequest request = new GeocodingApplyRequest(
                List.of(new GeocodingApplyRequest.Item("Toumodi", 6.55, -5.0167)));
        when(tripStopRepository.updateCoordinatesByCityLabel("Toumodi", 6.55, -5.0167)).thenReturn(2);

        GeocodingApplyResponse response = service.apply(request);

        assertEquals(1, response.appliedCount());
        assertEquals(List.of("Toumodi"), response.appliedCityLabels());
    }

    @Test
    void apply_noMatchingRows_notCountedAsApplied() {
        GeocodingApplyRequest request = new GeocodingApplyRequest(
                List.of(new GeocodingApplyRequest.Item("Inconnu", 1.0, 1.0)));
        when(tripStopRepository.updateCoordinatesByCityLabel("Inconnu", 1.0, 1.0)).thenReturn(0);

        GeocodingApplyResponse response = service.apply(request);

        assertEquals(0, response.appliedCount());
    }
}
