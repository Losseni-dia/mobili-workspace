package com.mobili.backend.module.station.service;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.city.entity.City;
import com.mobili.backend.module.city.entity.Country;
import com.mobili.backend.module.city.repository.CityRepository;
import com.mobili.backend.module.city.service.CityLookupService;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.station.dto.StationRequestDTO;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.RoleRepository;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

/**
 * Couvre uniquement resolveCity (via create()) — le reste de StationService (génération de code,
 * chauffeurs affiliés...) est hors scope de ce chantier Pays/Villes. requirePartnerOwner et le
 * contrôle de mot de passe sont mockés/satisfaits juste assez pour atteindre resolveCity, jamais
 * réellement exercés ici.
 */
@ExtendWith(MockitoExtension.class)
class StationServiceTest {

    @Mock private StationRepository stationRepository;
    @Mock private PartnerService partnerService;
    @Mock private UserRepository userRepository;
    @Mock private RoleRepository roleRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private TripRepository tripRepository;
    @Mock private CityRepository cityRepository;
    @Mock private CityLookupService cityLookupService;
    @Mock private UserPrincipal principal;

    private StationService service;

    @BeforeEach
    void setUp() {
        service = new StationService(stationRepository, partnerService, userRepository,
                roleRepository, passwordEncoder, tripRepository, cityRepository, cityLookupService);
    }

    private Country country(long id, String iso) {
        Country c = new Country();
        c.setId(id);
        c.setIsoCode(iso);
        c.setName(iso);
        return c;
    }

    private StationRequestDTO validDto(Long cityId) {
        StationRequestDTO dto = new StationRequestDTO();
        dto.setName("Gare Adjamé");
        dto.setCityId(cityId);
        dto.setPassword("secret123");
        return dto;
    }

    @Test
    void create_cityFromAnotherCountry_rejected() {
        Partner partner = new Partner();
        partner.setId(1L);
        partner.setCountry(country(1L, "CI"));
        when(partnerService.getCurrentPartnerForOperations()).thenReturn(partner);

        City parisCity = new City();
        parisCity.setId(9L);
        parisCity.setName("Paris");
        parisCity.setCountry(country(2L, "FR"));
        when(cityRepository.findById(9L)).thenReturn(Optional.of(parisCity));

        assertThrows(MobiliException.class, () -> service.create(validDto(9L), principal));
    }

    @Test
    void create_noCityIdNorCityName_rejected() {
        Partner partner = new Partner();
        partner.setId(1L);
        partner.setCountry(country(1L, "CI"));
        when(partnerService.getCurrentPartnerForOperations()).thenReturn(partner);

        StationRequestDTO dto = validDto(null);
        assertThrows(MobiliException.class, () -> service.create(dto, principal));
    }

    @Test
    void create_unknownCityName_delegatesToCityLookupService() {
        Partner partner = new Partner();
        partner.setId(1L);
        Country ci = country(1L, "CI");
        partner.setCountry(ci);
        when(partnerService.getCurrentPartnerForOperations()).thenReturn(partner);

        StationRequestDTO dto = validDto(null);
        dto.setCityName("Zuenoula");
        City created = new City();
        created.setId(42L);
        created.setName("Zuenoula");
        created.setCountry(ci);
        when(cityLookupService.resolveOrCreatePending("Zuenoula", ci)).thenReturn(created);
        when(passwordEncoder.encode(any())).thenReturn("hashed");
        // saveAndFlush renvoie le même objet, déjà pourvu d'un code par
        // applyNewStationDefaults() avant l'appel — findById le retrouve tel quel (capturé dans
        // ce tableau d'une case), le bloc de secours (code manquant) de create() n'est donc
        // jamais exercé ici.
        var savedHolder = new com.mobili.backend.module.station.entity.Station[1];
        when(stationRepository.saveAndFlush(any())).thenAnswer(inv -> {
            var s = (com.mobili.backend.module.station.entity.Station) inv.getArgument(0);
            s.setId(100L);
            savedHolder[0] = s;
            return s;
        });
        when(stationRepository.findById(100L)).thenAnswer(inv -> Optional.of(savedHolder[0]));

        // Ne doit pas lever d'exception : la ville inconnue est déléguée à CityLookupService,
        // jamais bloquante.
        org.junit.jupiter.api.Assertions.assertDoesNotThrow(
                () -> service.create(dto, principal));
    }
}
