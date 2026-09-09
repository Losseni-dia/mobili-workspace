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
                List.of(new GeocodingApplyRequest.Item("Toumodi", 6.55, -5.0167, null)));
        when(tripStopRepository.updateCoordinatesByCityLabel("Toumodi", 6.55, -5.0167)).thenReturn(2);

        GeocodingApplyResponse response = service.apply(request);

        assertEquals(1, response.appliedCount());
        assertEquals(List.of("Toumodi"), response.appliedCityLabels());
    }

    @Test
    void apply_noMatchingRows_notCountedAsApplied() {
        GeocodingApplyRequest request = new GeocodingApplyRequest(
                List.of(new GeocodingApplyRequest.Item("Inconnu", 1.0, 1.0, null)));
        when(tripStopRepository.updateCoordinatesByCityLabel("Inconnu", 1.0, 1.0)).thenReturn(0);

        GeocodingApplyResponse response = service.apply(request);

        assertEquals(0, response.appliedCount());
    }

    @Test
    void apply_withNewCityLabel_renamesAndAppliesCoordinates() {
        GeocodingApplyRequest request = new GeocodingApplyRequest(
                List.of(new GeocodingApplyRequest.Item("Coto", 6.3654, 2.4183, "Cotonou")));
        when(tripStopRepository.renameAndUpdateCoordinatesByCityLabel("Coto", "Cotonou", 6.3654, 2.4183))
                .thenReturn(3);

        GeocodingApplyResponse response = service.apply(request);

        assertEquals(1, response.appliedCount());
        assertEquals(List.of("Coto"), response.appliedCityLabels());
        org.mockito.Mockito.verify(tripStopRepository)
                .renameAndUpdateCoordinatesByCityLabel("Coto", "Cotonou", 6.3654, 2.4183);
        org.mockito.Mockito.verify(tripStopRepository, org.mockito.Mockito.never())
                .updateCoordinatesByCityLabel(org.mockito.ArgumentMatchers.anyString(),
                        org.mockito.ArgumentMatchers.anyDouble(), org.mockito.ArgumentMatchers.anyDouble());
    }

    @Test
    void apply_newCityLabelEqualsCityLabel_notTreatedAsRename() {
        GeocodingApplyRequest request = new GeocodingApplyRequest(
                List.of(new GeocodingApplyRequest.Item("Toumodi", 6.55, -5.0167, "Toumodi")));
        when(tripStopRepository.updateCoordinatesByCityLabel("Toumodi", 6.55, -5.0167)).thenReturn(1);

        service.apply(request);

        org.mockito.Mockito.verify(tripStopRepository)
                .updateCoordinatesByCityLabel("Toumodi", 6.55, -5.0167);
        org.mockito.Mockito.verifyNoMoreInteractions(tripStopRepository);
    }

    @Test
    void geocodeOne_success_returnsItemWithoutTouchingRepository() {
        when(mapboxGeocodingService.geocode("Touba", "CI")).thenReturn(new GeocodingResult(8.2833, -7.6833));

        var item = service.geocodeOne("Touba", "CI");

        assertEquals("Touba", item.cityLabel());
        assertEquals(8.2833, item.latitude());
        assertFalse(item.ambiguous());
        org.mockito.Mockito.verifyNoInteractions(tripStopRepository);
    }

    @Test
    void geocodeOne_ambiguousNameWithoutCountry_flagged() {
        when(mapboxGeocodingService.geocode("Touba", null)).thenReturn(new GeocodingResult(14.86, -15.87));

        var item = service.geocodeOne("Touba", null);

        assertTrue(item.ambiguous());
    }

    @Test
    void geocodeOne_geocodingFails_returnsFailureItem() {
        when(mapboxGeocodingService.geocode("Pogo", null))
                .thenThrow(new GeocodingFailedException("Aucun résultat"));

        var item = service.geocodeOne("Pogo", null);

        assertNull(item.latitude());
        assertEquals("Aucun résultat", item.errorMessage());
    }
}
