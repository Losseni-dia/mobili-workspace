package com.mobili.backend.api.passenger.trip;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.city.dto.CityOption;
import com.mobili.backend.module.city.dto.CountryOption;
import com.mobili.backend.module.city.repository.CityRepository;
import com.mobili.backend.module.city.repository.CountryRepository;
import com.mobili.backend.module.tracking.service.LiveTrackingTokenService;
import com.mobili.backend.module.trip.dto.TripEtaResponse;
import com.mobili.backend.module.trip.dto.TripResponseDTO;
import com.mobili.backend.module.trip.dto.TripStopResponseDTO;
import com.mobili.backend.module.trip.dto.mapper.TripMapper;
import com.mobili.backend.module.trip.entity.TransportType;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStatus;
import com.mobili.backend.module.trip.service.TripEtaService;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/trips")
@RequiredArgsConstructor
public class TripReadController {

    private final TripService tripService;
    private final TripMapper tripMapper;
    private final TripRunService tripRunService;
    private final AnalyticsEventService analyticsEventService;
    private final CityRepository cityRepository;
    private final CountryRepository countryRepository;
    private final TripEtaService tripEtaService;
    private final LiveTrackingTokenService liveTrackingTokenService;

    @GetMapping("/cities")
    public List<String> getCities(
            @RequestParam(required = false, defaultValue = "") String q) {
        return cityRepository.findByNameStartingWith(
                q != null ? q.trim().toLowerCase() : "");
    }

    /** Liste des pays — endpoint public (même règle que /trips/cities), utilisé par l'inscription
     *  société (choix du pays) et la création de gare (filtrage des villes par pays). Miroir de
     *  GET /admin/cities/countries mais accessible sans droit admin. */
    @GetMapping("/countries")
    public List<CountryOption> getCountries() {
        return countryRepository.findAllByOrderByNameAsc().stream()
                .map(c -> new CountryOption(c.getId(), c.getName(), c.getIsoCode(), c.getContinent()))
                .toList();
    }

    /** Villes filtrées par pays — utilisé par la création de gare (une gare ne peut être que dans
     *  le pays de sa société, voir StationService.resolveCity) et, à terme, la sélection des
     *  arrêts de trajet. Villes non vérifiées incluses (verified=false) : sélectionnables tout de
     *  suite, l'admin affine la géoloc ensuite (écran Pays & Villes). */
    @GetMapping("/cities/by-country")
    public List<CityOption> getCitiesByCountry(
            @RequestParam Long countryId,
            @RequestParam(required = false, defaultValue = "") String q) {
        String query = q != null ? q.trim() : "";
        return cityRepository.findByCountryIdAndNameStartingWith(countryId, query).stream()
                .map(c -> new CityOption(c.getId(), c.getName(), c.getLatitude(), c.getLongitude(), c.isVerified()))
                .toList();
    }

    @GetMapping
    public List<TripResponseDTO> getAll(
            @RequestParam(name = "transportType", required = false) String transportType) {
        TransportType tt = parseTransportType(transportType);
        return tripService.findAllUpcoming(tt).stream()
                .map(this::toDtoWithNextStop)
                .peek(TripReadController::stripPublicOrganizerAndChauffeurIdentity)
                .collect(Collectors.toList());
    }

    /**
     * Retire l'identité (nom, prénom, photo) de l'organisateur covoiturage / chauffeur assigné
     * des réponses accessibles sans authentification (catalogue {@code GET /trips}, recherche
     * {@code GET /trips/search} — y compris les pages indexables /trajets/** qui appellent ce
     * dernier). Corrige une fuite de données personnelles : n'importe qui pouvait jusqu'ici
     * scraper nom + photo d'un chauffeur en itérant simplement les trajets, sans compte. Le détail
     * d'un trajet précis ({@code GET /trips/{id}}, désormais authentifié — voir
     * MobiliApiPaths.TRIPS_DETAIL) continue lui de renvoyer ces champs, seul contexte légitime
     * (un utilisateur connecté qui consulte/réserve CE trajet).
     */
    private static void stripPublicOrganizerAndChauffeurIdentity(TripResponseDTO dto) {
        dto.setCovoiturageOrganizerFirstname(null);
        dto.setCovoiturageOrganizerLastname(null);
        dto.setCovoiturageOrganizerDriverPhotoUrl(null);
        dto.setAssignedChauffeurFirstname(null);
        dto.setAssignedChauffeurLastname(null);
    }

    /** Catalogue voyageur : "En route vers X" pour les trajets déjà partis. */
    private TripResponseDTO toDtoWithNextStop(Trip trip) {
        TripResponseDTO dto = tripMapper.toDto(trip);
        if (trip.getStatus() == TripStatus.EN_COURS) {
            dto.setNextStopCity(tripRunService.nextStopCityOrNull(trip));
        }
        return dto;
    }

    @GetMapping("/{id}/stops")
    public List<TripStopResponseDTO> listStops(@PathVariable Long id) {
        return tripService.listStops(id);
    }

    /**
     * ETA vers le prochain arrêt — appelé par l'app passager toutes les 5 min pendant qu'un
     * écran de suivi est ouvert (jamais à chaque position GPS reçue via Firestore, qui arrive
     * toutes les 10-15s). {@code lat}/{@code lng} : dernière position du véhicule connue côté
     * client (reçue via Firestore, pas stockée côté backend — voir TripEtaService).
     */
    @GetMapping("/{id}/eta")
    public TripEtaResponse getEta(
            @PathVariable Long id,
            @RequestParam double lat,
            @RequestParam double lng) {
        return tripEtaService.getEta(id, lat, lng);
    }

    /**
     * Jeton Firebase pour la lecture de la position temps réel (Firestore) — voir
     * LiveTrackingTokenService (vérifie uniquement que le trajet est EN_COURS). Ouvert à
     * n'importe quel utilisateur connecté, pas seulement aux passagers ayant réservé CE trajet
     * (ex. un proche qui veut suivre le véhicule d'un voyageur sans avoir lui-même de billet) —
     * la seule barrière est d'avoir un compte Mobili (@AuthenticationPrincipal ci-dessous).
     */
    @GetMapping("/{id}/live-tracking-token")
    public java.util.Map<String, String> getLiveTrackingToken(
            @PathVariable Long id, @AuthenticationPrincipal UserPrincipal principal) {
        String token = liveTrackingTokenService.mintPassengerToken(id, principal.getUser().getId());
        return java.util.Map.of("token", token);
    }

    @GetMapping("/{id}")
    public TripResponseDTO getById(@PathVariable Long id) {
        Trip trip = tripService.findById(id);
        TripResponseDTO dto = toDtoWithNextStop(trip);
        dto.setLegFares(tripService.listLegFares(id));
        return dto;
    }

    @GetMapping("/search")
    public List<TripResponseDTO> search(
            @RequestParam(required = false, defaultValue = "") String departure,
            @RequestParam(required = false, defaultValue = "") String arrival,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(name = "transportType", required = false) String transportType) {

        TransportType tt = parseTransportType(transportType);
        List<Trip> results = tripService.searchTrips(departure, arrival, date, tt);

        String depT = departure != null ? departure.trim() : "";
        String arrT = arrival != null ? arrival.trim() : "";
        if (results.isEmpty() && (!depT.isEmpty() || !arrT.isEmpty())) {
            String payload = String.format(
                    "{\"dep\":\"%s\",\"arr\":\"%s\",\"date\":%s}",
                    escapeJson(depT),
                    escapeJson(arrT),
                    date != null ? "\"" + date + "\"" : "null");
            analyticsEventService.record(AnalyticsEventType.SEARCH_NO_RESULT, null, payload);
        }

        return results.stream()
                .map(this::toDtoWithNextStop)
                .peek(TripReadController::stripPublicOrganizerAndChauffeurIdentity)
                .collect(Collectors.toList());
    }

    private static TransportType parseTransportType(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return TransportType.valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private static String escapeJson(String s) {
        if (s == null) {
            return "";
        }
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    @GetMapping("/my-trips")
    public List<TripResponseDTO> getMyTrips() {
        return tripService.findMyTrips().stream()
                .map(tripMapper::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/my-trips/range")
    public List<TripResponseDTO> getMyTripsInRange(
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate toDate,
            @RequestParam(required = false) Long stationId) {
        return tripService.findMyTripsInRange(fromDate, toDate, stationId).stream()
                .map(tripMapper::toDto)
                .collect(Collectors.toList());
    }
}