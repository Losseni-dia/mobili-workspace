package com.mobili.backend.api.passenger.trip;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.booking.booking.dto.BookingResponseDTO;
import com.mobili.backend.module.booking.booking.dto.mapper.BookingMapper;
import com.mobili.backend.module.partner.dto.PartnerDashboardResponse;
import com.mobili.backend.module.partner.dto.RecentBookingDTO;
import com.mobili.backend.module.partner.dto.mapper.PartnerMapper;
import com.mobili.backend.module.partner.service.PartnerDashboardService;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.trip.dto.CovoiturageSoloTripRequestDTO;
import com.mobili.backend.module.trip.dto.TripResponseDTO;
import com.mobili.backend.module.trip.dto.mapper.TripMapper;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.service.TripService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

import java.util.Map;

/**
 * Trajets covoiturage particulier (hors compagnie) : publication par le conducteur,
 * rattachement à un partenaire technique côté serveur.
 */
@RestController
@RequestMapping("/covoiturage/trips")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('CHAUFFEUR', 'ADMIN')")
public class CovoiturageSoloTripController {

    private final TripService tripService;
    private final BookingService bookingService;
    private final TripMapper tripMapper;
    private final BookingMapper bookingMapper;
    private final PartnerDashboardService partnerDashboardService;
    private final PartnerMapper partnerMapper;


    /**
     * Demandes covoiturage en attente de décision pour ce trajet — nom,
     * prénom et photo du passager uniquement (voir BookingResponseDTO).
     */
    @GetMapping("/{id}/pending-requests")
    public List<BookingResponseDTO> pendingRequests(
            @PathVariable Long id, @AuthenticationPrincipal UserPrincipal principal) {
        return bookingService.findPendingCovoiturageRequestsForTrip(id, principal).stream()
                .map(bookingMapper::toDto)
                .toList();
    }

    @PostMapping("/{tripId}/bookings/{bookingId}/accept")
    public void acceptBookingRequest(
            @PathVariable Long tripId, @PathVariable Long bookingId,
            @AuthenticationPrincipal UserPrincipal principal) {
        bookingService.acceptCovoiturageRequest(bookingId, principal);
    }

    @PostMapping("/{tripId}/bookings/{bookingId}/reject")
    public void rejectBookingRequest(
            @PathVariable Long tripId, @PathVariable Long bookingId,
            @AuthenticationPrincipal UserPrincipal principal) {
        bookingService.rejectCovoiturageRequest(bookingId, principal);
    }



    /**
     * Liste des trajets covoiturage du conducteur. La racine {@code GET /v1/covoiturage/trips} est un alias
     * de {@code /mine} (évite des 404 inutiles et des confusions côté outils / navigateur).
     */
    @GetMapping({ "", "/mine" })
    public List<TripResponseDTO> myTrips(@AuthenticationPrincipal UserPrincipal principal) {
        return tripService.findMyCovoiturageSoloTrips(principal).stream()
                .map(this::toDtoWithLegFares)
                .toList();
    }

    /**
     * {@code consumes} explicite sur {@code multipart/form-data} a pu empêcher le matching
     * selon le client (boundary, navigateur) ; le corps est toujours attendu en multipart
     * pour les parts {@code trip} + optionnellement {@code vehicleImage}.
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TripResponseDTO create(
            @RequestPart("trip") @Valid CovoiturageSoloTripRequestDTO dto,
            @RequestPart(value = "vehicleImage", required = false) MultipartFile vehicleImage,
            @AuthenticationPrincipal UserPrincipal principal) {
        Trip saved = tripService.createCovoiturageSoloTrip(dto, vehicleImage, principal);
        return toDtoWithLegFares(saved);
    }

    @PutMapping("/{id}")
    public TripResponseDTO update(
            @PathVariable Long id,
            @RequestPart("trip") @Valid CovoiturageSoloTripRequestDTO dto,
            @RequestPart(value = "vehicleImage", required = false) MultipartFile vehicleImage,
            @AuthenticationPrincipal UserPrincipal principal) {
        Trip saved = tripService.updateCovoiturageSoloTrip(id, dto, vehicleImage, principal);
        return toDtoWithLegFares(saved);
    }

    @GetMapping("/{id}/bookings")
    public List<BookingResponseDTO> tripBookings(
            @PathVariable Long id, @AuthenticationPrincipal UserPrincipal principal) {
        return tripService.findBookingsForCovoiturageSoloTrip(id, principal).stream()
                .map(bookingMapper::toDto)
                .toList();
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(
            @PathVariable Long id, @AuthenticationPrincipal UserPrincipal principal) {
        tripService.deleteCovoiturageSoloTrip(id, principal);
    }

    /**
     * Synthèse "gare/partenaire" pour le conducteur covoiturage : trajets,
     * réservations, revenus — scopée sur SES trajets uniquement (jamais le
     * partenaire technique du pool, partagé par tous les conducteurs).
     */
    @GetMapping("/dashboard/stats")
    public PartnerDashboardResponse dashboardStats(@AuthenticationPrincipal UserPrincipal principal) {
        Map<String, Object> rawData =
                partnerDashboardService.getDashboardDataForCovoiturageOrganizer(principal.getUser().getId());

        @SuppressWarnings("unchecked")
        List<RecentBookingDTO> recentBookings =
                partnerMapper.toRecentBookingDtoList((List<Booking>) rawData.get("bookingsList"));

        return PartnerDashboardResponse.builder()
                .activeTripsCount((long) rawData.get("activeTrips"))
                .totalBookingsCount((long) rawData.get("totalBookings"))
                .totalRevenue((double) rawData.get("totalRevenue"))
                .revenueOnline((double) rawData.get("revenueOnline"))
                .revenueOffline((double) rawData.get("revenueOffline"))
                .recentBookings(recentBookings)
                .build();
    }

    private TripResponseDTO toDtoWithLegFares(Trip t) {
        TripResponseDTO dto = tripMapper.toDto(t);
        dto.setLegFares(tripService.listLegFares(t.getId()));
        return dto;
    }
}
