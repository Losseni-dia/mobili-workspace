package com.mobili.backend.module.admin.service;

import com.mobili.backend.module.admin.dto.AdminCityApplyRequest;
import com.mobili.backend.module.admin.dto.AdminCityApplyResponse;
import com.mobili.backend.module.admin.dto.AdminCityPreviewResponse;
import com.mobili.backend.module.city.entity.City;
import com.mobili.backend.module.city.entity.Country;
import com.mobili.backend.module.city.repository.CityRepository;
import com.mobili.backend.module.city.repository.CountryRepository;
import com.mobili.backend.module.routing.exception.GeocodingFailedException;
import com.mobili.backend.module.routing.mapbox.dto.GeocodingResult;
import com.mobili.backend.module.routing.mapbox.service.MapboxGeocodingService;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminCityServiceTest {

    @Mock
    private CityRepository cityRepository;
    @Mock
    private CountryRepository countryRepository;
    @Mock
    private MapboxGeocodingService mapboxGeocodingService;

    private AdminCityService service;

    @BeforeEach
    void setUp() {
        service = new AdminCityService(cityRepository, countryRepository, mapboxGeocodingService);
    }

    private Country country(long id, String iso) {
        Country c = new Country();
        c.setId(id);
        c.setIsoCode(iso);
        c.setName("Côte d'Ivoire");
        return c;
    }

    private City city(long id, String name, Country country) {
        City c = new City();
        c.setId(id);
        c.setName(name);
        c.setCountry(country);
        c.setVerified(false);
        return c;
    }

    @Test
    void preview_pendingCityWithCountry_geocodesRestrictedToThatCountry() {
        Country ci = country(1L, "CI");
        City toumodi = city(10L, "Toumodi", ci);
        when(cityRepository.findByVerifiedFalseOrderByName()).thenReturn(List.of(toumodi));
        when(mapboxGeocodingService.geocode("Toumodi", "CI")).thenReturn(new GeocodingResult(6.55, -5.0167));

        AdminCityPreviewResponse response = service.preview();

        assertEquals(1, response.items().size());
        var item = response.items().get(0);
        assertEquals(10L, item.id());
        assertEquals(6.55, item.latitude());
        assertFalse(item.ambiguous());
    }

    @Test
    void preview_pendingCityWithoutCountry_ambiguousNameFlagged() {
        City touba = city(11L, "Touba", null);
        when(cityRepository.findByVerifiedFalseOrderByName()).thenReturn(List.of(touba));
        when(mapboxGeocodingService.geocode("Touba", null)).thenReturn(new GeocodingResult(14.86, -15.87));

        AdminCityPreviewResponse response = service.preview();

        assertTrue(response.items().get(0).ambiguous());
    }

    @Test
    void preview_geocodingFails_returnsFailureItemInsteadOfThrowing() {
        City pogo = city(12L, "Pogo", null);
        when(cityRepository.findByVerifiedFalseOrderByName()).thenReturn(List.of(pogo));
        when(mapboxGeocodingService.geocode("Pogo", null))
                .thenThrow(new GeocodingFailedException("Aucun résultat"));

        AdminCityPreviewResponse response = service.preview();

        var item = response.items().get(0);
        assertNull(item.latitude());
        assertEquals("Aucun résultat", item.errorMessage());
    }

    @Test
    void apply_validItem_marksVerifiedAndUpdatesCoordinates() {
        Country ci = country(1L, "CI");
        City toumodi = city(10L, "Toumodi", ci);
        when(cityRepository.findById(10L)).thenReturn(Optional.of(toumodi));

        AdminCityApplyRequest request = new AdminCityApplyRequest(
                List.of(new AdminCityApplyRequest.Item(10L, null, null, 6.55, -5.0167)));

        AdminCityApplyResponse response = service.apply(request);

        assertEquals(1, response.appliedCount());
        assertTrue(toumodi.isVerified());
        assertEquals(6.55, toumodi.getLatitude());
    }

    @Test
    void apply_withRename_updatesNameToo() {
        City coto = city(13L, "Coto", null);
        when(cityRepository.findById(13L)).thenReturn(Optional.of(coto));

        AdminCityApplyRequest request = new AdminCityApplyRequest(
                List.of(new AdminCityApplyRequest.Item(13L, "Cotonou", null, 6.3654, 2.4183)));

        service.apply(request);

        assertEquals("Cotonou", coto.getName());
        assertTrue(coto.isVerified());
    }

    @Test
    void apply_unknownCityId_notCountedAsApplied() {
        when(cityRepository.findById(999L)).thenReturn(Optional.empty());

        AdminCityApplyRequest request = new AdminCityApplyRequest(
                List.of(new AdminCityApplyRequest.Item(999L, null, null, 1.0, 1.0)));

        AdminCityApplyResponse response = service.apply(request);

        assertEquals(0, response.appliedCount());
    }
}
