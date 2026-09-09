package com.mobili.backend.module.admin.service;

import com.mobili.backend.module.admin.dto.GeocodingApplyRequest;
import com.mobili.backend.module.admin.dto.GeocodingApplyResponse;
import com.mobili.backend.module.admin.dto.GeocodingPreviewItem;
import com.mobili.backend.module.admin.dto.GeocodingPreviewResponse;
import com.mobili.backend.module.routing.exception.GeocodingFailedException;
import com.mobili.backend.module.routing.mapbox.dto.GeocodingResult;
import com.mobili.backend.module.routing.mapbox.service.MapboxGeocodingService;
import com.mobili.backend.module.trip.repository.TripStopRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Écran admin de géocodage des city_label de trip_stops encore sans coordonnées — voir
 * scripts/GeocodeTripStopCities.java, dont cette classe reprend la même logique (filtre
 * anti-test, biais géographique, alerte sur les noms ambigus), exposée en API plutôt qu'en
 * script à lancer manuellement en SSH. Toujours en deux temps : preview() ne modifie jamais la
 * base, seul apply() écrit — et uniquement les lignes explicitement validées par l'admin.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class AdminTripStopGeocodingService {

    /** Voir scripts/GeocodeTripStopCities.java — mêmes motifs, même limite documentée : filtre
     *  basique, une relecture humaine reste nécessaire. */
    private static final Pattern[] EXCLUDE_PATTERNS = {
        Pattern.compile("^(.)\\1{2,}$", Pattern.CASE_INSENSITIVE),
        Pattern.compile("^ville desservie \\d+$", Pattern.CASE_INSENSITIVE),
        Pattern.compile("^none$", Pattern.CASE_INSENSITIVE),
        Pattern.compile(".* - .* - .*"),
    };

    /** Noms connus pour exister dans plusieurs pays — voir historique "Touba" CI vs SN. */
    private static final Set<String> AMBIGUOUS_NAMES = Set.of("touba");

    private final TripStopRepository tripStopRepository;
    private final MapboxGeocodingService mapboxGeocodingService;

    @Transactional(readOnly = true)
    public GeocodingPreviewResponse preview() {
        List<String> cityLabels = tripStopRepository.findDistinctCityLabelsMissingCoordinates();
        List<GeocodingPreviewItem> items = new ArrayList<>();

        for (String cityLabel : cityLabels) {
            if (looksLikeTestData(cityLabel)) {
                items.add(GeocodingPreviewItem.excludedAsTestData(cityLabel));
                continue;
            }
            boolean ambiguous = AMBIGUOUS_NAMES.contains(cityLabel.trim().toLowerCase());
            try {
                GeocodingResult result = mapboxGeocodingService.geocode(cityLabel);
                items.add(GeocodingPreviewItem.success(
                        cityLabel, result.latitude(), result.longitude(), ambiguous));
            } catch (GeocodingFailedException e) {
                items.add(GeocodingPreviewItem.failure(cityLabel, e.getMessage()));
            }
        }

        log.info("ℹ️ Aperçu géocodage : {} ville(s) trouvée(s), {} traitée(s) par Mapbox.",
                cityLabels.size(), items.size());
        return new GeocodingPreviewResponse(items);
    }

    @Transactional
    public GeocodingApplyResponse apply(GeocodingApplyRequest request) {
        List<String> applied = new ArrayList<>();
        for (GeocodingApplyRequest.Item item : request.getItems()) {
            boolean rename = item.getNewCityLabel() != null
                    && !item.getNewCityLabel().isBlank()
                    && !item.getNewCityLabel().equals(item.getCityLabel());

            int updated = rename
                    ? tripStopRepository.renameAndUpdateCoordinatesByCityLabel(
                            item.getCityLabel(), item.getNewCityLabel(), item.getLatitude(), item.getLongitude())
                    : tripStopRepository.updateCoordinatesByCityLabel(
                            item.getCityLabel(), item.getLatitude(), item.getLongitude());

            if (updated > 0) {
                applied.add(item.getCityLabel());
                if (rename) {
                    log.info("✅ '{}' renommé en '{}' et coordonnées appliquées ({} arrêt(s)) : {}, {}",
                            item.getCityLabel(), item.getNewCityLabel(), updated, item.getLatitude(), item.getLongitude());
                } else {
                    log.info("✅ Coordonnées appliquées pour '{}' ({} arrêt(s)) : {}, {}",
                            item.getCityLabel(), updated, item.getLatitude(), item.getLongitude());
                }
            } else {
                log.warn("⚠️ Aucun trip_stop trouvé pour city_label='{}' — rien appliqué.", item.getCityLabel());
            }
        }
        return new GeocodingApplyResponse(applied.size(), applied);
    }

    /**
     * Re-géocode une seule requête (nom corrigé et/ou pays choisi par l'admin) sans toucher la
     * base — utilisé par les actions "Modifier le nom" et "Re-géocoder avec un pays" de l'écran,
     * pour rafraîchir l'aperçu d'une ligne avant de la valider avec apply().
     */
    public GeocodingPreviewItem geocodeOne(String query, String countryCode) {
        boolean ambiguous = AMBIGUOUS_NAMES.contains(query.trim().toLowerCase())
                && (countryCode == null || countryCode.isBlank());
        try {
            GeocodingResult result = mapboxGeocodingService.geocode(query, countryCode);
            return GeocodingPreviewItem.success(query, result.latitude(), result.longitude(), ambiguous);
        } catch (GeocodingFailedException e) {
            return GeocodingPreviewItem.failure(query, e.getMessage());
        }
    }

    private boolean looksLikeTestData(String cityLabel) {
        for (Pattern pattern : EXCLUDE_PATTERNS) {
            if (pattern.matcher(cityLabel).matches() || pattern.matcher(cityLabel).find()) {
                return true;
            }
        }
        return false;
    }
}
