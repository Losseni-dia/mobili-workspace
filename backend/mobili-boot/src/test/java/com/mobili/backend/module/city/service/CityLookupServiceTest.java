package com.mobili.backend.module.city.service;

import com.mobili.backend.module.city.entity.City;
import com.mobili.backend.module.city.entity.Country;
import com.mobili.backend.module.city.repository.CityRepository;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CityLookupServiceTest {

    @Mock
    private CityRepository cityRepository;

    private CityLookupService service;

    private Country country(String isoCode) {
        Country c = new Country();
        c.setId(1L);
        c.setIsoCode(isoCode);
        c.setName("Côte d'Ivoire");
        return c;
    }

    @Test
    void resolveOrCreatePending_existingCity_returnsItWithoutCreating() {
        service = new CityLookupService(cityRepository);
        City existing = new City();
        existing.setId(5L);
        existing.setName("Bouaké");
        when(cityRepository.findByNameIgnoreCase("Bouaké")).thenReturn(Optional.of(existing));

        City result = service.resolveOrCreatePending("Bouaké", country("CI"));

        assertSame(existing, result);
        verify(cityRepository, org.mockito.Mockito.never()).save(any());
    }

    @Test
    void resolveOrCreatePending_unknownCity_createsUnverifiedWithoutCoordinates() {
        service = new CityLookupService(cityRepository);
        when(cityRepository.findByNameIgnoreCase("Zuenoula")).thenReturn(Optional.empty());
        when(cityRepository.save(any(City.class))).thenAnswer(inv -> inv.getArgument(0));
        Country ci = country("CI");

        City result = service.resolveOrCreatePending(" Zuenoula ", ci);

        ArgumentCaptor<City> captor = ArgumentCaptor.forClass(City.class);
        verify(cityRepository).save(captor.capture());
        City saved = captor.getValue();
        assertEquals("Zuenoula", saved.getName());
        assertEquals(ci, saved.getCountry());
        assertFalse(saved.isVerified());
        assertNull(saved.getLatitude());
        assertSame(result, saved);
    }
}
