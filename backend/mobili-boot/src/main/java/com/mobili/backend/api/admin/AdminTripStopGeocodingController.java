package com.mobili.backend.api.admin;

import com.mobili.backend.module.admin.dto.GeocodingApplyRequest;
import com.mobili.backend.module.admin.dto.GeocodingApplyResponse;
import com.mobili.backend.module.admin.dto.GeocodingPreviewItem;
import com.mobili.backend.module.admin.dto.GeocodingPreviewResponse;
import com.mobili.backend.module.admin.service.AdminTripStopGeocodingService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Écran admin de géocodage des arrêts de trajet sans coordonnées — voir
 * AdminTripStopGeocodingService pour la logique (reprend scripts/GeocodeTripStopCities.java,
 * exposé en API plutôt qu'en script SSH manuel). Couvert par la règle de sécurité globale sur
 * /admin/** (voir SecurityConfig/MobiliApiPaths) — pas de @PreAuthorize ici, convention déjà
 * suivie par les autres contrôleurs de ce package.
 */
@RestController
@RequestMapping("/admin/trip-stops-geocoding")
@RequiredArgsConstructor
@Slf4j
public class AdminTripStopGeocodingController {

    private final AdminTripStopGeocodingService adminTripStopGeocodingService;

    @GetMapping("/preview")
    public GeocodingPreviewResponse preview() {
        log.info("GET /v1/admin/trip-stops-geocoding/preview");
        return adminTripStopGeocodingService.preview();
    }

    @PostMapping("/apply")
    public GeocodingApplyResponse apply(@Valid @RequestBody GeocodingApplyRequest request) {
        log.info("POST /v1/admin/trip-stops-geocoding/apply — {} ligne(s)", request.getItems().size());
        return adminTripStopGeocodingService.apply(request);
    }

    /**
     * Re-géocode une seule requête sans toucher la base — actions "Modifier le nom" (query =
     * nom corrigé) et "Re-géocoder avec un pays" (country renseigné) de l'écran admin.
     */
    @GetMapping("/geocode-one")
    public GeocodingPreviewItem geocodeOne(
            @RequestParam String query,
            @RequestParam(required = false) String country) {
        log.info("GET /v1/admin/trip-stops-geocoding/geocode-one — query='{}', country={}", query, country);
        return adminTripStopGeocodingService.geocodeOne(query, country);
    }
}
