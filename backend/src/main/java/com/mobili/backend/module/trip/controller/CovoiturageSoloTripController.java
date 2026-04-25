package com.mobili.backend.module.trip.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.trip.dto.CovoiturageSoloTripRequestDTO;
import com.mobili.backend.module.trip.dto.TripResponseDTO;
import com.mobili.backend.module.trip.dto.mapper.TripMapper;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.service.TripService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Trajets covoiturage particulier (hors compagnie) : publication par le conducteur,
 * rattachement à un partenaire technique côté serveur.
 */
@RestController
@RequestMapping("/v1/covoiturage/trips")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('CHAUFFEUR', 'ADMIN')")
public class CovoiturageSoloTripController {

    private final TripService tripService;
    private final TripMapper tripMapper;

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

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(
            @PathVariable Long id, @AuthenticationPrincipal UserPrincipal principal) {
        tripService.deleteCovoiturageSoloTrip(id, principal);
    }

    private TripResponseDTO toDtoWithLegFares(Trip t) {
        TripResponseDTO dto = tripMapper.toDto(t);
        dto.setLegFares(tripService.listLegFares(t.getId()));
        return dto;
    }
}
