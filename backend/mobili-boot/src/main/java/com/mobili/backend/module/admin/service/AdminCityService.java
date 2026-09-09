package com.mobili.backend.module.admin.service;

import com.mobili.backend.module.admin.dto.AdminCityApplyRequest;
import com.mobili.backend.module.admin.dto.AdminCityApplyResponse;
import com.mobili.backend.module.admin.dto.AdminCityPreviewItem;
import com.mobili.backend.module.admin.dto.AdminCityPreviewResponse;
import com.mobili.backend.module.admin.dto.CountryOption;
import com.mobili.backend.module.city.entity.City;
import com.mobili.backend.module.city.entity.Country;
import com.mobili.backend.module.city.repository.CityRepository;
import com.mobili.backend.module.city.repository.CountryRepository;
import com.mobili.backend.module.routing.exception.GeocodingFailedException;
import com.mobili.backend.module.routing.mapbox.dto.GeocodingResult;
import com.mobili.backend.module.routing.mapbox.service.MapboxGeocodingService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Écran admin Pays & Villes — même pattern preview/apply que
 * AdminTripStopGeocodingService (écran de géocodage des arrêts), mais cible directement les
 * lignes `City` (id) plutôt que des city_label de TripStop en texte libre. Cible en priorité les
 * villes {@code verified=false} : créées à la volée via CityLookupService (gare ou trajet avec
 * une ville absente de la liste proposée), jamais bloquantes pour le flux appelant, mais en
 * attente de contrôle admin avant d'être proposées à d'autres partenaires.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class AdminCityService {

    /** Noms connus pour exister dans plusieurs pays — voir historique "Touba" CI vs SN (écran
     *  de géocodage des arrêts). Ambiguïté seulement si le pays n'est pas déjà renseigné. */
    private static final Set<String> AMBIGUOUS_NAMES = Set.of("touba");

    private final CityRepository cityRepository;
    private final CountryRepository countryRepository;
    private final MapboxGeocodingService mapboxGeocodingService;

    @Transactional(readOnly = true)
    public AdminCityPreviewResponse preview() {
        List<City> pending = cityRepository.findByVerifiedFalseOrderByName();
        List<AdminCityPreviewItem> items = new ArrayList<>();

        for (City city : pending) {
            Country country = city.getCountry();
            String countryCode = country != null ? country.getIsoCode() : null;
            boolean ambiguous = countryCode == null
                    && AMBIGUOUS_NAMES.contains(city.getName().trim().toLowerCase());
            try {
                GeocodingResult result = mapboxGeocodingService.geocode(city.getName(), countryCode);
                items.add(AdminCityPreviewItem.success(
                        city.getId(), city.getName(),
                        country != null ? country.getId() : null,
                        country != null ? country.getName() : null,
                        result.latitude(), result.longitude(), ambiguous));
            } catch (GeocodingFailedException e) {
                items.add(AdminCityPreviewItem.failure(
                        city.getId(), city.getName(),
                        country != null ? country.getId() : null,
                        country != null ? country.getName() : null,
                        e.getMessage()));
            }
        }

        log.info("ℹ️ Aperçu Pays & Villes : {} ville(s) en attente de validation.", items.size());
        return new AdminCityPreviewResponse(items);
    }

    @Transactional
    public AdminCityApplyResponse apply(AdminCityApplyRequest request) {
        List<String> applied = new ArrayList<>();
        for (AdminCityApplyRequest.Item item : request.getItems()) {
            City city = cityRepository.findById(item.getId()).orElse(null);
            if (city == null) {
                log.warn("⚠️ Ville #{} introuvable — rien appliqué.", item.getId());
                continue;
            }
            if (item.getName() != null && !item.getName().isBlank()) {
                city.setName(item.getName().trim());
            }
            if (item.getCountryId() != null) {
                countryRepository.findById(item.getCountryId()).ifPresent(city::setCountry);
            }
            city.setLatitude(item.getLatitude());
            city.setLongitude(item.getLongitude());
            city.setVerified(true);
            cityRepository.save(city);
            applied.add(city.getName());
            log.info("✅ Ville '{}' validée : {}, {}", city.getName(), item.getLatitude(), item.getLongitude());
        }
        return new AdminCityApplyResponse(applied.size(), applied);
    }

    /** Re-géocode une ville (nom corrigé et/ou pays choisi) sans toucher la base — même principe
     *  que geocodeOne de l'écran de géocodage des arrêts. */
    public AdminCityPreviewItem geocodeOne(Long cityId, String name, String countryCode) {
        boolean ambiguous = (countryCode == null || countryCode.isBlank())
                && AMBIGUOUS_NAMES.contains(name.trim().toLowerCase());
        try {
            GeocodingResult result = mapboxGeocodingService.geocode(name, countryCode);
            return AdminCityPreviewItem.success(cityId, name, null, null,
                    result.latitude(), result.longitude(), ambiguous);
        } catch (GeocodingFailedException e) {
            return AdminCityPreviewItem.failure(cityId, name, null, null, e.getMessage());
        }
    }

    @Transactional(readOnly = true)
    public List<CountryOption> listCountries() {
        return countryRepository.findAllByOrderByNameAsc().stream()
                .map(c -> new CountryOption(c.getId(), c.getName(), c.getIsoCode(), c.getContinent()))
                .toList();
    }
}
