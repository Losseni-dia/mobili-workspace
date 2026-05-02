package com.mobili.backend.api.partner;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal; // Important
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.trip.dto.TripPricePreviewRequest;
import com.mobili.backend.module.trip.dto.TripPricePreviewResponse;
import com.mobili.backend.module.trip.dto.TripRequestDTO;
import com.mobili.backend.module.trip.dto.TripResponseDTO;
import com.mobili.backend.module.trip.dto.mapper.TripMapper;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.service.TripService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/v1/trips")
@RequiredArgsConstructor
public class TripWriteController {

    private final TripService tripService;
    private final TripMapper tripMapper;

    @PostMapping(value = "/price-preview", consumes = MediaType.APPLICATION_JSON_VALUE)
    @PreAuthorize("hasAnyRole('PARTNER', 'GARE', 'ADMIN')")
    public TripPricePreviewResponse previewSegmentPrice(@Valid @RequestBody TripPricePreviewRequest body) {
        return tripService.previewSegmentPrice(body);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('PARTNER', 'GARE', 'ADMIN')")
    public TripResponseDTO create(
            @RequestPart("trip") @Valid TripRequestDTO dto,
            @RequestPart(value = "vehicleImage", required = false) MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal) {

        Trip entity = tripMapper.toEntity(dto);

        // On délègue tout au nouveau service (image + partenaire)
        return tripMapper.toDto(tripService.save(entity, file, principal, dto));
    }

    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('PARTNER', 'GARE', 'ADMIN')")
    public TripResponseDTO update(
            @PathVariable Long id,
            @RequestPart("trip") @Valid TripRequestDTO dto, // Changé en @RequestPart
            @RequestPart(value = "vehicleImage", required = false) MultipartFile file,
            @AuthenticationPrincipal UserPrincipal principal) {

        dto.setId(id);
        Trip entity = tripMapper.toEntity(dto);

        // Ton service save() gère déjà l'update si l'ID est présent
        return tripMapper.toDto(tripService.save(entity, file, principal, dto));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('PARTNER', 'GARE', 'ADMIN')")
    public void delete(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal principal) {
        tripService.delete(id, principal);
    }
}