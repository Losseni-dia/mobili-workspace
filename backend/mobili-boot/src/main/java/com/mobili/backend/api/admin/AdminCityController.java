package com.mobili.backend.api.admin;

import com.mobili.backend.module.admin.dto.AdminCityApplyRequest;
import com.mobili.backend.module.admin.dto.AdminCityApplyResponse;
import com.mobili.backend.module.admin.dto.AdminCityPreviewItem;
import com.mobili.backend.module.admin.dto.AdminCityPreviewResponse;
import com.mobili.backend.module.admin.dto.CountryOption;
import com.mobili.backend.module.admin.service.AdminCityService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Écran admin Pays & Villes — même structure que AdminTripStopGeocodingController (preview/apply
 * en deux temps, jamais d'écriture avant validation explicite de l'admin). Couvert par la règle
 * de sécurité globale sur /admin/** (voir SecurityConfig/MobiliApiPaths) — pas de @PreAuthorize
 * ici, convention déjà suivie par les autres contrôleurs de ce package.
 */
@RestController
@RequestMapping("/admin/cities")
@RequiredArgsConstructor
@Slf4j
public class AdminCityController {

    private final AdminCityService adminCityService;

    @GetMapping("/preview")
    public AdminCityPreviewResponse preview() {
        log.info("GET /v1/admin/cities/preview");
        return adminCityService.preview();
    }

    @PostMapping("/apply")
    public AdminCityApplyResponse apply(@Valid @RequestBody AdminCityApplyRequest request) {
        log.info("POST /v1/admin/cities/apply — {} ligne(s)", request.getItems().size());
        return adminCityService.apply(request);
    }

    /** Re-géocode une ville (nom corrigé et/ou pays choisi) sans toucher la base. */
    @GetMapping("/geocode-one")
    public AdminCityPreviewItem geocodeOne(
            @RequestParam Long cityId,
            @RequestParam String name,
            @RequestParam(required = false) String country) {
        log.info("GET /v1/admin/cities/geocode-one — cityId={}, name='{}', country={}", cityId, name, country);
        return adminCityService.geocodeOne(cityId, name, country);
    }

    /** Liste des pays — pour les <select> de cet écran, et à terme les formulaires
     *  société/gare. */
    @GetMapping("/countries")
    public List<CountryOption> countries() {
        return adminCityService.listCountries();
    }
}
