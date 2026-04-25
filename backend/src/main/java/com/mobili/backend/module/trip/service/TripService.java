package com.mobili.backend.module.trip.service;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import org.springframework.security.core.context.SecurityContextHolder;

import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.trip.bootstrap.CovoiturageSoloPartnerBootstrap;
import com.mobili.backend.module.trip.dto.CovoiturageSoloTripRequestDTO;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.CovoiturageKycStatus;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.station.service.StationService;
import com.mobili.backend.module.trip.dto.TripLegFareResponse;
import com.mobili.backend.module.trip.dto.TripLegFareRequest;
import com.mobili.backend.module.trip.dto.TripPricePreviewRequest;
import com.mobili.backend.module.trip.dto.TripPricePreviewResponse;
import com.mobili.backend.module.trip.dto.TripRequestDTO;
import com.mobili.backend.module.trip.dto.TripStopResponseDTO;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.trip.dto.chauffeur.ChauffeurTripListItem;
import com.mobili.backend.module.trip.dto.chauffeur.ChauffeurTripsOverviewResponse;
import com.mobili.backend.module.trip.dto.driver.DriverLuggageSummaryResponse;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStatus;
import com.mobili.backend.module.trip.entity.TripStop;
import com.mobili.backend.module.trip.entity.TransportType;
import com.mobili.backend.module.trip.entity.VehicleType;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;
import com.mobili.backend.shared.sharedService.UploadService;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Service
@RequiredArgsConstructor
public class TripService {

    private final TripRepository tripRepository;
    private final BookingRepository bookingRepository;
    private final PartnerService partenaireService;
    private final UploadService uploadService;
    private final TripStopSyncService tripStopSyncService;
    private final TripRunService tripRunService;
    private final TripPricingService tripPricingService;
    private final AnalyticsEventService analyticsEventService;
    private final StationService stationService;
    private final UserRepository userRepository;
    private final CovoiturageSoloPartnerBootstrap covoiturageSoloPartnerBootstrap;

    @Transactional(readOnly = true)
    public List<Trip> findMyTrips() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UserPrincipal up)) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Non authentifié");
        }
        Partner partner = partenaireService.getCurrentPartnerForOperations();
        if (up.getStationId() != null) {
            return tripRepository.findAllByPartnerIdAndStationId(partner.getId(), up.getStationId());
        }
        return tripRepository.findAllByPartnerId(partner.getId());
    }

    @Transactional(readOnly = true)
    public List<Trip> findMyCovoiturageSoloTrips(UserPrincipal principal) {
        User u = userRepository
                .findById(principal.getUser().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Utilisateur introuvable"));
        if (!Boolean.TRUE.equals(u.getCovoiturageSoloProfile())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Liste réservée aux comptes covoiturage particulier.");
        }
        return tripRepository.findAllByCovoiturageOrganizerId(u.getId());
    }

    @Transactional
    public Trip createCovoiturageSoloTrip(
            CovoiturageSoloTripRequestDTO dto, MultipartFile vehicleImage, UserPrincipal principal) {
        User user = userRepository
                .findByIdWithEverything(principal.getUser().getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Utilisateur introuvable"));
        if (!Boolean.TRUE.equals(user.getCovoiturageSoloProfile())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Publication réservée aux comptes covoiturage particulier.");
        }
        if (!user.isEnabled()) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Compte inactif.");
        }
        if (user.getCovoiturageKycStatus() != CovoiturageKycStatus.APPROVED) {
            throw new MobiliException(
                    MobiliErrorCode.VALIDATION_ERROR,
                    "Votre profil covoiturage doit être validé par un administrateur avant toute publication.");
        }
        Partner pool = covoiturageSoloPartnerBootstrap.getPoolPartner();
        Trip trip = new Trip();
        trip.setDepartureCity(dto.getDepartureCity().trim());
        trip.setArrivalCity(dto.getArrivalCity().trim());
        trip.setBoardingPoint(dto.getBoardingPoint().trim());
        String plate = dto.getVehiculePlateNumber() != null && !dto.getVehiculePlateNumber().isBlank()
                ? dto.getVehiculePlateNumber().trim()
                : (user.getCovoiturageVehiclePlate() != null ? user.getCovoiturageVehiclePlate() : null);
        if (plate == null || plate.isBlank()) {
            throw new MobiliException(
                    MobiliErrorCode.VALIDATION_ERROR, "Immatriculation requise (saisie ou profil covoiturage).");
        }
        trip.setVehiculePlateNumber(plate.toUpperCase(Locale.ROOT));
        trip.setVehicleType(dto.getVehicleType());
        trip.setDepartureDateTime(dto.getDepartureDateTime());
        trip.setPrice(dto.getPrice());
        trip.setTotalSeats(dto.getTotalSeats());
        trip.setAvailableSeats(dto.getTotalSeats());
        trip.setStatus(TripStatus.PROGRAMMÉ);
        trip.setTransportType(TransportType.COVOITURAGE);
        trip.setMoreInfo(dto.getMoreInfo() != null && !dto.getMoreInfo().isBlank() ? dto.getMoreInfo().trim() : null);
        trip.setPartner(pool);
        trip.setCovoiturageOrganizer(user);
        trip.setStation(null);
        trip.setOriginDestinationPrice(null);
        if (vehicleImage != null && !vehicleImage.isEmpty()) {
            trip.setVehicleImageUrl(uploadService.saveImage(vehicleImage, "vehicles"));
        } else if (user.getCovoiturageVehiclePhotoUrl() != null
                && !user.getCovoiturageVehiclePhotoUrl().isBlank()) {
            trip.setVehicleImageUrl(user.getCovoiturageVehiclePhotoUrl());
        }
        trip.setIncludedCabinBagsPerPassenger(1);
        trip.setIncludedHoldBagsPerPassenger(1);
        trip.setMaxExtraHoldBagsPerPassenger(1);
        trip.setExtraHoldBagPrice(0.0);
        trip.setStops(new ArrayList<>());
        tripStopSyncService.syncStopsForTrip(trip);
        Trip saved = tripRepository.save(trip);
        tripPricingService.clearSegmentFaresForTrip(saved.getId());
        analyticsEventService.record(
                AnalyticsEventType.TRIP_PUBLISHED,
                user.getId(),
                String.format("{\"tripId\":%d,\"covoiturageSolo\":true}", saved.getId()));
        return findById(saved.getId());
    }

    @Transactional
    public void deleteCovoiturageSoloTrip(Long id, UserPrincipal principal) {
        Trip t = findById(id);
        if (t.getCovoiturageOrganizer() == null) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Ce n'est pas une offre covoiturage particulier.");
        }
        boolean admin = principal.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        if (!admin
                && !t.getCovoiturageOrganizer()
                        .getId()
                        .equals(principal.getUser().getId())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Vous n'êtes pas l'organisateur de ce voyage.");
        }
        tripPricingService.clearSegmentFaresForTrip(id);
        tripRepository.delete(t);
    }

    // --- RECHERCHE (terminus + étapes dans moreInfo, ordre : départ → étapes CSV → arrivée) ---
    @Transactional(readOnly = true)
    public List<Trip> searchTrips(String departure, String arrival, LocalDate date) {
        return searchTrips(departure, arrival, date, null);
    }

    @Transactional(readOnly = true)
    public List<Trip> searchTrips(String departure, String arrival, LocalDate date, TransportType transportType) {
        LocalDateTime startSearch = (date != null)
                ? date.atStartOfDay()
                : LocalDateTime.now();

        List<Trip> candidates = tripRepository.findAllUpcomingTrips(startSearch);
        String dep = normalizeQuery(departure);
        String arr = normalizeQuery(arrival);

        if (dep == null && arr == null) {
            return filterByTransport(candidates, transportType);
        }

        return candidates.stream()
                .filter(t -> transportType == null || t.getTransportType() == transportType)
                .filter(t -> matchesRouteSearch(t, dep, arr))
                .collect(Collectors.toList());
    }

    private List<Trip> filterByTransport(List<Trip> trips, TransportType transportType) {
        if (transportType == null) {
            return trips;
        }
        return trips.stream()
                .filter(t -> t.getTransportType() == transportType)
                .collect(Collectors.toList());
    }

    /**
     * Chaîne ordonnée des villes : departureCity, segments de moreInfo (séparés par
     * virgule), arrivalCity.
     * Convention : moreInfo = villes intermédiaires uniquement (sans répéter départ
     * / arrivée).
     */
    List<String> buildCityChain(Trip trip) {
        List<String> chain = new ArrayList<>();
        chain.add(normalizeCityToken(trip.getDepartureCity()));
        if (trip.getMoreInfo() != null && !trip.getMoreInfo().isBlank()) {
            for (String part : trip.getMoreInfo().split(",")) {
                String token = normalizeCityToken(part);
                if (!token.isEmpty() && !chain.get(chain.size() - 1).equals(token)) {
                    chain.add(token);
                }
            }
        }
        String arrivalToken = normalizeCityToken(trip.getArrivalCity());
        if (chain.isEmpty() || !chain.get(chain.size() - 1).equals(arrivalToken)) {
            chain.add(arrivalToken);
        }
        return chain;
    }

    private boolean matchesRouteSearch(Trip trip, String depQuery, String arrQuery) {
        List<String> chain = buildCityChain(trip);
        if (depQuery != null && arrQuery != null) {
            return hasValidSegment(chain, depQuery, arrQuery);
        }
        if (depQuery != null) {
            return chain.stream().anyMatch(city -> partialCityMatch(city, depQuery));
        }
        return chain.stream().anyMatch(city -> partialCityMatch(city, arrQuery));
    }

    /** Il existe i &lt; j avec départ et arrivée recherchés sur ces positions (préfixe insensible à la casse). */
    private boolean hasValidSegment(List<String> chain, String depQuery, String arrQuery) {
        for (int i = 0; i < chain.size(); i++) {
            if (!partialCityMatch(chain.get(i), depQuery)) {
                continue;
            }
            for (int j = i + 1; j < chain.size(); j++) {
                if (partialCityMatch(chain.get(j), arrQuery)) {
                    return true;
                }
            }
        }
        return false;
    }

    private static boolean partialCityMatch(String cityNorm, String queryNorm) {
        if (queryNorm == null || queryNorm.isEmpty()) {
            return true;
        }
        return cityNorm.startsWith(queryNorm);
    }

    private static String normalizeCityToken(String raw) {
        if (raw == null) {
            return "";
        }
        return raw.trim().toLowerCase(Locale.ROOT);
    }

    private static String normalizeQuery(String raw) {
        if (raw == null) {
            return null;
        }
        String t = raw.trim();
        return t.isEmpty() ? null : t.toLowerCase(Locale.ROOT);
    }

    // --- READ ---
    // Dans TripService.java
    @Transactional(readOnly = true)
    public List<Trip> findAllUpcoming() {
        return findAllUpcoming(null);
    }

    @Transactional(readOnly = true)
    public List<Trip> findAllUpcoming(TransportType transportType) {
        // On récupère les trajets (avec ta marge de 5h pour être sûr de les voir)
        List<Trip> trips = tripRepository.findAllUpcomingTrips(LocalDateTime.now().minusHours(5));
        if (transportType != null) {
            trips = trips.stream()
                    .filter(t -> t.getTransportType() == transportType)
                    .collect(Collectors.toList());
        }
        // ASTUCE : On "touche" l'objet partenaire pour forcer Hibernate à le charger
        trips.forEach(trip -> {
            if (trip.getPartner() != null) {
                trip.getPartner().getName();
            }
        });
        return trips;
    }

    @Transactional
    public Trip findById(Long id) {
        Trip trip = tripRepository.findByIdWithPartnerAndStops(id)
                .orElseThrow(() -> new MobiliException(
                        MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Voyage introuvable (ID: " + id + ")"));
        if (trip.getStops() == null || trip.getStops().isEmpty()) {
            tripStopSyncService.syncStopsForTrip(trip);
            trip = tripRepository.save(trip);
        }
        if (trip.getPartner() != null) {
            trip.getPartner().getName();
        }
        return trip;
    }

    @Transactional(readOnly = true)
    public List<TripLegFareResponse> listLegFares(Long tripId) {
        return tripPricingService.listLegFareResponses(tripId);
    }

    @Transactional
    public Trip save(Trip trip, MultipartFile tripImage, UserPrincipal principal, TripRequestDTO requestDto) {
        final boolean isNew = trip.getId() == null;
        List<TripLegFareRequest> legFares = requestDto.getLegFares();
        Long stationIdFromDto = requestDto.getStationId();
        Partner partner = partenaireService.getCurrentPartnerForOperations();
        trip.setPartner(partner);
        Trip existingTrip = null;
        if (trip.getId() != null) {
            existingTrip = tripRepository.findById(trip.getId())
                    .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Trajet introuvable"));
            assertTripWriteAccess(existingTrip, principal, partner);
            if (tripImage == null || tripImage.isEmpty()) {
                trip.setVehicleImageUrl(existingTrip.getVehicleImageUrl());
            }
            if (trip.getStatus() == null) {
                trip.setStatus(existingTrip.getStatus());
            }
            applyStationOnWrite(trip, principal, partner, stationIdFromDto, existingTrip);
        } else {
            if (trip.getStatus() == null) {
                trip.setStatus(TripStatus.PROGRAMMÉ);
            }
            applyStationOnWrite(trip, principal, partner, stationIdFromDto, null);
        }
        applyAssignedChauffeur(trip, requestDto, existingTrip);

        if (trip.getTransportType() == null) {
            trip.setTransportType(
                    existingTrip != null && existingTrip.getTransportType() != null
                            ? existingTrip.getTransportType()
                            : TransportType.PUBLIC);
        }

        applyLuggagePolicyFromRequest(trip, requestDto, existingTrip);

        // 2. Validation prix (OK)
        if (trip.getPrice() != null && trip.getPrice() < 0) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Le prix ne peut pas être négatif");
        }

        // 3. Traitement de la NOUVELLE image (si fournie)
        if (tripImage != null && !tripImage.isEmpty()) {
            String path = uploadService.saveImage(tripImage, "vehicles");
            trip.setVehicleImageUrl(path);
        }

        if (trip.getStops() == null) {
            trip.setStops(new ArrayList<>());
        }
        tripStopSyncService.syncStopsForTrip(trip);

        if (legFares != null && !legFares.isEmpty()) {
            double sum = tripPricingService.validateConsecutiveLegFaresAndSum(trip, legFares);
            tripRunService.ensureStops(trip);
            int lastIdx = tripRunService.lastStopIndex(trip);
            if (lastIdx > 1) {
                if (trip.getOriginDestinationPrice() == null || trip.getOriginDestinationPrice() <= 0) {
                    throw new MobiliException(
                            MobiliErrorCode.VALIDATION_ERROR,
                            "Indiquez le prix du trajet complet (départ → arrivée) : il peut différer de la somme des tronçons.");
                }
                trip.setPrice(trip.getOriginDestinationPrice());
            } else {
                trip.setPrice(sum);
                trip.setOriginDestinationPrice(null);
            }
        } else {
            trip.setOriginDestinationPrice(null);
        }

        Trip saved = tripRepository.save(trip);

        if (isNew) {
            analyticsEventService.record(
                    AnalyticsEventType.TRIP_PUBLISHED,
                    principal.getUser().getId(),
                    String.format("{\"tripId\":%d,\"partnerId\":%d}", saved.getId(), partner.getId()));
        }

        if (legFares != null) {
            if (legFares.isEmpty()) {
                tripPricingService.clearSegmentFaresForTrip(saved.getId());
            } else {
                tripPricingService.replaceConsecutiveLegFares(saved, legFares);
            }
        }

        return saved;
    }

    private void applyLuggagePolicyFromRequest(Trip trip, TripRequestDTO req, Trip existing) {
        if (req.getIncludedCabinBagsPerPassenger() != null) {
            trip.setIncludedCabinBagsPerPassenger(req.getIncludedCabinBagsPerPassenger());
        } else if (existing != null && existing.getIncludedCabinBagsPerPassenger() != null) {
            trip.setIncludedCabinBagsPerPassenger(existing.getIncludedCabinBagsPerPassenger());
        }
        if (trip.getIncludedCabinBagsPerPassenger() == null) {
            trip.setIncludedCabinBagsPerPassenger(1);
        }

        if (req.getIncludedHoldBagsPerPassenger() != null) {
            trip.setIncludedHoldBagsPerPassenger(req.getIncludedHoldBagsPerPassenger());
        } else if (existing != null && existing.getIncludedHoldBagsPerPassenger() != null) {
            trip.setIncludedHoldBagsPerPassenger(existing.getIncludedHoldBagsPerPassenger());
        }
        if (trip.getIncludedHoldBagsPerPassenger() == null) {
            trip.setIncludedHoldBagsPerPassenger(1);
        }

        if (req.getMaxExtraHoldBagsPerPassenger() != null) {
            trip.setMaxExtraHoldBagsPerPassenger(req.getMaxExtraHoldBagsPerPassenger());
        } else if (existing != null && existing.getMaxExtraHoldBagsPerPassenger() != null) {
            trip.setMaxExtraHoldBagsPerPassenger(existing.getMaxExtraHoldBagsPerPassenger());
        }
        if (trip.getMaxExtraHoldBagsPerPassenger() == null) {
            trip.setMaxExtraHoldBagsPerPassenger(1);
        }

        if (req.getExtraHoldBagPrice() != null) {
            trip.setExtraHoldBagPrice(req.getExtraHoldBagPrice());
        } else if (existing != null && existing.getExtraHoldBagPrice() != null) {
            trip.setExtraHoldBagPrice(existing.getExtraHoldBagPrice());
        }
        if (trip.getExtraHoldBagPrice() == null) {
            trip.setExtraHoldBagPrice(0.0);
        }
    }

    @Transactional(readOnly = true)
    public DriverLuggageSummaryResponse getDriverLuggageSummary(Long tripId) {
        Trip trip = findById(tripId);
        int cab = trip.getIncludedCabinBagsPerPassenger() != null ? trip.getIncludedCabinBagsPerPassenger() : 1;
        int hold = trip.getIncludedHoldBagsPerPassenger() != null ? trip.getIncludedHoldBagsPerPassenger() : 1;
        int maxExtra = trip.getMaxExtraHoldBagsPerPassenger() != null ? trip.getMaxExtraHoldBagsPerPassenger() : 1;
        double price = trip.getExtraHoldBagPrice() != null ? trip.getExtraHoldBagPrice() : 0.0;

        int seats = bookingRepository.sumConfirmedSeatsForTrip(tripId);
        int extraSum = bookingRepository.sumExtraHoldBagsForTrip(tripId);

        DriverLuggageSummaryResponse r = new DriverLuggageSummaryResponse();
        r.setIncludedCabinBagsPerPassenger(cab);
        r.setIncludedHoldBagsPerPassenger(hold);
        r.setMaxExtraHoldBagsPerPassenger(maxExtra);
        r.setExtraHoldBagPrice(price);
        r.setConfirmedPassengerSeats(seats);
        r.setExpectedIncludedCabinBags(seats * cab);
        r.setExpectedIncludedHoldBags(seats * hold);
        r.setTotalExtraHoldBagsReserved(extraSum);
        r.setMaxPossibleExtraHoldBags(seats * maxExtra);
        return r;
    }

    private void assertTripWriteAccess(Trip existing, UserPrincipal p, Partner currentPartner) {
        if (!existing.getPartner().getId().equals(currentPartner.getId())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Voyage d'un autre partenaire");
        }
        if (p.getStationId() != null) {
            if (existing.getStation() == null
                    || !existing.getStation().getId().equals(p.getStationId())) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Ce voyage n'appartient pas à votre gare");
            }
        }
    }

    private void applyStationOnWrite(
            Trip trip, UserPrincipal principal, Partner partner, Long stationIdFromDto, Trip existing) {
        if (principal.getStationId() != null) {
            Station st = stationService.getStationForPartnerOrThrow(principal.getStationId(), partner.getId());
            trip.setStation(st);
            stationService.assertStationOperationalForTripUse(st);
            return;
        }
        if (stationIdFromDto != null) {
            Station st = stationService.getStationForPartnerOrThrow(stationIdFromDto, partner.getId());
            trip.setStation(st);
            stationService.assertStationOperationalForTripUse(st);
        } else if (existing != null) {
            trip.setStation(existing.getStation());
            if (trip.getStation() != null) {
                stationService.assertStationOperationalForTripUse(trip.getStation());
            }
        } else {
            trip.setStation(null);
        }
    }

    /**
     * Affectation chauffeur (dispatch gare de préférence ; le partenaire peut aussi). Mise à jour : {@code null}
     * = conserver ; {@code 0} = retirer.
     */
    private void applyAssignedChauffeur(Trip trip, TripRequestDTO dto, Trip existingTrip) {
        Trip covoitRef = existingTrip != null ? existingTrip : trip;
        if (covoitRef.getCovoiturageOrganizer() != null) {
            trip.setAssignedChauffeur(null);
            return;
        }

        Long req = dto.getAssignedChauffeurId();
        if (existingTrip != null) {
            if (req == null) {
                trip.setAssignedChauffeur(existingTrip.getAssignedChauffeur());
                return;
            }
            if (req == 0L) {
                trip.setAssignedChauffeur(null);
                return;
            }
        } else {
            if (req == null || req == 0L) {
                trip.setAssignedChauffeur(null);
                return;
            }
        }

        User chauffeur = resolveAndValidateChauffeurForTrip(req, trip);
        trip.setAssignedChauffeur(chauffeur);
    }

    private User resolveAndValidateChauffeurForTrip(Long chauffeurId, Trip trip) {
        User u = userRepository
                .findByIdWithEverything(chauffeurId)
                .orElseThrow(
                        () -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Chauffeur introuvable."));
        boolean isChauffeur = u.getRoles().stream().anyMatch(r -> r.getName() == UserRole.CHAUFFEUR);
        if (!isChauffeur) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "L'utilisateur n'est pas un chauffeur.");
        }
        if (u.getEmployerPartner() == null
                || !u.getEmployerPartner().getId().equals(trip.getPartner().getId())) {
            throw new MobiliException(
                    MobiliErrorCode.VALIDATION_ERROR,
                    "Le chauffeur n'appartient pas à la compagnie de ce trajet.");
        }
        if (trip.getStation() != null) {
            if (u.getChauffeurAffiliationStation() == null
                    || !u.getChauffeurAffiliationStation().getId().equals(trip.getStation().getId())) {
                throw new MobiliException(
                        MobiliErrorCode.VALIDATION_ERROR,
                        "Choisissez un chauffeur affecté à la gare de ce trajet.");
            }
        }
        return u;
    }

    @Transactional
    public void delete(Long id, UserPrincipal principal) {
        Trip t = findById(id);
        assertTripWriteAccess(t, principal, partenaireService.getCurrentPartnerForOperations());
        tripPricingService.clearSegmentFaresForTrip(id);
        tripRepository.delete(t);
    }

    /**
     * Console conducteur : covoiturage « solo » = organisateur seulement ; sinon logique
     * partenaire / gare ; les chauffeurs compagnies conservent l’accès aux trajets sans
     * organisateur.
     */
    @Transactional(readOnly = true)
    public void assertPartnerOrGareCanOperateDriverTrip(Long tripId, UserPrincipal principal) {
        Trip t = findById(tripId);
        boolean isAdmin = principal.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        if (isAdmin) {
            return;
        }
        if (t.getCovoiturageOrganizer() != null) {
            if (!t.getCovoiturageOrganizer().getId().equals(principal.getUser().getId())) {
                throw new MobiliException(
                        MobiliErrorCode.ACCESS_DENIED, "Ce voyage est réservé à son organisateur covoiturage.");
            }
            return;
        }
        if (principal.getAuthorities().stream().anyMatch(a -> "ROLE_CHAUFFEUR".equals(a.getAuthority()))) {
            assertChauffeurLineTripOrThrow(t, principal);
            return;
        }
        Partner cp = partenaireService.getCurrentPartnerForOperations();
        if (!t.getPartner().getId().equals(cp.getId())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Voyage d'un autre partenaire");
        }
        if (principal.getStationId() != null) {
            if (t.getStation() == null
                    || !t.getStation().getId().equals(principal.getStationId())) {
                throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Hors périmètre de votre gare");
            }
        }
    }

    /**
     * Trajet ligne (hors covoiturage organisateur) : conducteur affecté, ou salarié de la compagnie si pas encore
     * d’affectation sur le voyage.
     */
    private void assertChauffeurLineTripOrThrow(Trip t, UserPrincipal principal) {
        long userId = principal.getUser().getId();
        if (t.getAssignedChauffeur() != null) {
            if (!t.getAssignedChauffeur().getId().equals(userId)) {
                throw new MobiliException(
                        MobiliErrorCode.ACCESS_DENIED, "Ce voyage est reserve a un autre conducteur.");
            }
            return;
        }
        User u = userRepository
                .findByIdWithEverything(userId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Utilisateur introuvable."));
        if (u.getEmployerPartner() != null && u.getEmployerPartner().getId().equals(t.getPartner().getId())) {
            return;
        }
        throw new MobiliException(
                MobiliErrorCode.ACCESS_DENIED,
                "Aucun acces a ce voyage (conducteur designe ou compagnie employeur requis).");
    }

    @Transactional
    public void startChauffeurTrip(Long tripId, UserPrincipal principal) {
        assertPartnerOrGareCanOperateDriverTrip(tripId, principal);
        Trip trip = findById(tripId);
        if (trip.getStatus() == TripStatus.ANNULÉ) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Voyage annule.");
        }
        if (trip.getStatus() == TripStatus.TERMINÉ) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Voyage deja termine.");
        }
        trip.setStatus(TripStatus.EN_COURS);
        tripRepository.save(trip);
        tripRunService.ensureStops(trip);
        int firstStop = trip.getStops().stream()
                .map(TripStop::getStopIndex)
                .min(Comparator.naturalOrder())
                .orElse(0);
        tripRunService.recordDepartureFromStop(trip, firstStop, LocalDateTime.now());
    }

    @Transactional(readOnly = true)
    public ChauffeurTripsOverviewResponse getChauffeurTripsOverview(UserPrincipal principal) {
        long uid = principal.getUser().getId();
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime fromWindow = now.minusDays(1L);

        List<Trip> assignedUp = tripRepository.findAssignedChauffeurUpcoming(uid, fromWindow);
        List<Trip> assignedHist =
                tripRepository.findAssignedChauffeurHistory(uid, now, PageRequest.of(0, 40));

        List<Trip> covoitAll = tripRepository.findAllByCovoiturageOrganizerId(uid);
        List<Trip> covoitUp = covoitAll.stream()
                .filter(t -> t.getStatus() != TripStatus.ANNULÉ && t.getStatus() != TripStatus.TERMINÉ)
                .filter(t -> t.getStatus() == TripStatus.EN_COURS
                        || t.getDepartureDateTime() == null
                        || !t.getDepartureDateTime().isBefore(fromWindow))
                .sorted(Comparator.comparing(Trip::getDepartureDateTime, Comparator.nullsLast(Comparator.naturalOrder())))
                .toList();
        List<Trip> covoitHi = covoitAll.stream()
                .filter(t -> t.getStatus() == TripStatus.TERMINÉ
                        || t.getStatus() == TripStatus.ANNULÉ
                        || (t.getStatus() == TripStatus.PROGRAMMÉ
                                && t.getDepartureDateTime() != null
                                && t.getDepartureDateTime().isBefore(now)))
                .sorted(Comparator.comparing(Trip::getDepartureDateTime, Comparator.nullsLast(Comparator.reverseOrder())))
                .limit(40)
                .toList();

        List<ChauffeurTripListItem> upcoming = Stream.concat(
                        assignedUp.stream().map(t -> toChauffeurItem(t, "ASSIGNED")),
                        covoitUp.stream().map(t -> toChauffeurItem(t, "COVOITURAGE")))
                .sorted(Comparator.comparing(ChauffeurTripListItem::getDepartureDateTime, Comparator.nullsLast(Comparator.naturalOrder())))
                .toList();

        List<ChauffeurTripListItem> history = Stream.concat(
                        assignedHist.stream().map(t -> toChauffeurItem(t, "ASSIGNED")),
                        covoitHi.stream().map(t -> toChauffeurItem(t, "COVOITURAGE")))
                .sorted(Comparator.comparing(ChauffeurTripListItem::getDepartureDateTime, Comparator.nullsLast(Comparator.reverseOrder())))
                .limit(50)
                .toList();

        ChauffeurTripsOverviewResponse res = new ChauffeurTripsOverviewResponse();
        res.setUpcoming(upcoming);
        res.setHistory(history);
        return res;
    }

    private static ChauffeurTripListItem toChauffeurItem(Trip t, String source) {
        ChauffeurTripListItem i = new ChauffeurTripListItem();
        i.setId(t.getId());
        i.setSource(source);
        i.setDepartureCity(t.getDepartureCity());
        i.setArrivalCity(t.getArrivalCity());
        i.setBoardingPoint(t.getBoardingPoint());
        i.setDepartureDateTime(t.getDepartureDateTime());
        i.setStatus(t.getStatus() != null ? t.getStatus().name() : null);
        if (t.getPartner() != null) {
            t.getPartner().getName();
            i.setPartnerName(t.getPartner().getName());
        }
        if (t.getStation() != null) {
            i.setStationName(t.getStation().getName());
        }
        i.setVehiculePlateNumber(t.getVehiculePlateNumber());
        if (t.getVehicleType() != null) {
            i.setVehicleType(t.getVehicleType().name());
        }
        return i;
    }

    /**
     * Liste les arrêts d'un voyage. Pas en {@code readOnly} car {@link #findById}
     * peut persister à la volée les arrêts manquants (ancien voyage migré sans
     * la table trip_stops alimentée).
     */
    @Transactional
    public List<TripStopResponseDTO> listStops(Long tripId) {
        Trip t = findById(tripId);
        return t.getStops().stream()
                .map(s -> new TripStopResponseDTO(s.getStopIndex(), s.getCityLabel(), s.getPlannedDepartureAt()))
                .toList();
    }

    /**
     * Prévisualisation tarif segment : même chaîne que la réservation (arrêts + prorata), sans persistance.
     */
    @Transactional(readOnly = true)
    public TripPricePreviewResponse previewSegmentPrice(TripPricePreviewRequest req) {
        Trip draft = createTransientTripForPreview(req);
        tripRunService.validateSegment(draft, req.getBoardingStopIndex(), req.getAlightingStopIndex());
        tripRunService.ensureStops(draft);
        int last = tripRunService.lastStopIndex(draft);
        double perSeat;
        if (req.getLegFares() != null && !req.getLegFares().isEmpty()) {
            tripPricingService.validateConsecutiveLegFaresAndSum(draft, req.getLegFares());
            if (req.getBoardingStopIndex() == 0
                    && req.getAlightingStopIndex() == last
                    && req.getOriginDestinationPrice() != null) {
                perSeat = req.getOriginDestinationPrice();
            } else {
                perSeat = tripPricingService.sumLegFaresForPath(
                        req.getLegFares(), req.getBoardingStopIndex(), req.getAlightingStopIndex());
            }
        } else {
            perSeat = tripPricingService.resolvePricePerSeat(
                    draft, req.getBoardingStopIndex(), req.getAlightingStopIndex());
        }
        List<TripStopResponseDTO> stops = draft.getStops().stream()
                .map(s -> new TripStopResponseDTO(s.getStopIndex(), s.getCityLabel(), s.getPlannedDepartureAt()))
                .toList();
        return new TripPricePreviewResponse(perSeat, last, stops);
    }

    private static Trip createTransientTripForPreview(TripPricePreviewRequest req) {
        Trip t = new Trip();
        t.setDepartureCity(req.getDepartureCity());
        t.setArrivalCity(req.getArrivalCity());
        t.setMoreInfo(req.getMoreInfo() != null ? req.getMoreInfo() : "");
        t.setPrice(req.getPrice());
        LocalDateTime when = req.getDepartureDateTime() != null ? req.getDepartureDateTime() : LocalDateTime.now();
        t.setDepartureDateTime(when);
        t.setVehiculePlateNumber("—");
        t.setTotalSeats(1);
        t.setAvailableSeats(1);
        t.setVehicleType(VehicleType.MASSA_NORMAL);
        t.setStops(new ArrayList<>());
        t.setOriginDestinationPrice(req.getOriginDestinationPrice());
        return t;
    }
}