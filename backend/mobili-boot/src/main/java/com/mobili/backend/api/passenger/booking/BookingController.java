package com.mobili.backend.api.passenger.booking;

import java.security.Principal;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.module.booking.booking.dto.BookingPricePreviewRequest;
import com.mobili.backend.module.booking.booking.dto.BookingPricePreviewResponse;
import com.mobili.backend.module.booking.booking.dto.BookingRequestDTO;
import com.mobili.backend.module.booking.booking.dto.BookingResponseDTO;
import com.mobili.backend.module.booking.booking.dto.ManualBlockRequest;
import com.mobili.backend.module.booking.booking.dto.mapper.BookingMapper;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/bookings")
public class BookingController {

  private final BookingService bookingService;
    private final BookingMapper bookingMapper;
    private final UserService userService;
    private final PartnerService partnerService;

    public BookingController(
            BookingService bookingService,
            BookingMapper bookingMapper,
            UserService userService,
            PartnerService partnerService) {
        this.bookingService = bookingService;
        this.bookingMapper = bookingMapper;
        this.userService = userService;
        this.partnerService = partnerService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('USER')")
    public BookingResponseDTO create(@RequestBody @Valid BookingRequestDTO dto, Principal principal) {
        User user = userService.findByLogin(principal.getName());
        dto.setUserId(user.getId());
        Booking booking = bookingService.create(dto);
        return bookingMapper.toDto(booking);
    }

    // Prévisualisation SANS créer de réservation — même séquence de calcul que create()
    // (BookingService.computePricing, partagée), pour que le passager voie le détail (sous-
    // total, forfait, bagages, total) avant de payer.
    @PostMapping("/price-preview")
    @PreAuthorize("hasRole('USER')")
    public BookingPricePreviewResponse previewPrice(@RequestBody @Valid BookingPricePreviewRequest dto) {
        BookingService.PricingBreakdown pricing = bookingService.previewPrice(
                dto.getTripId(), dto.getNumberOfSeats(), dto.getBoardingStopIndex(),
                dto.getAlightingStopIndex(), dto.getExtraHoldBags(), dto.getCouponCode());
        return BookingPricePreviewResponse.from(pricing);
    }

    @PatchMapping("/{id}/confirm")
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN', 'ROLE_STATION')")
    public void confirm(@PathVariable Long id) {
        bookingService.confirmPayment(id);
    }

    @GetMapping("/user/{userId}")
    @PreAuthorize("hasAnyAuthority('ROLE_ADMIN', 'ROLE_PARTNER', 'ROLE_GARE','ROLE_STATION') or #userId == authentication.principal.user.id")
    public List<BookingResponseDTO> getByUserId(@PathVariable Long userId) {
        return bookingService.findByUserId(userId).stream()
                .map(bookingMapper::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/trips/{tripId}/occupied-seats")
    public List<String> getOccupiedSeats(
            @PathVariable("tripId") Long tripId,
            @RequestParam(value = "boardingStopIndex", required = false) Integer boardingStopIndex,
            @RequestParam(value = "alightingStopIndex", required = false) Integer alightingStopIndex) {
        List<String> seats = bookingService.getOccupiedSeatNumbers(tripId, boardingStopIndex, alightingStopIndex);
        return seats != null ? seats : new ArrayList<>();
    }

    @GetMapping("/{id}")
    @PreAuthorize("isAuthenticated()")
    public BookingResponseDTO getById(@PathVariable Long id) {
        Booking booking = bookingService.findById(id);
        return bookingMapper.toDto(booking);
    }

    @GetMapping(path = "")
    @PreAuthorize("hasAuthority('ROLE_ADMIN')")
    public List<BookingResponseDTO> getAll() {
        return bookingService.findAll().stream()
                .map(bookingMapper::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/partner/my-bookings")
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN','ROLE_STATION')")
    public List<BookingResponseDTO> getPartnerBookings() {
        return bookingService.findMyPartnerBookings().stream()
                .map(bookingMapper::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/partner/my-bookings/range")
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN','ROLE_STATION')")
    public List<BookingResponseDTO> getPartnerBookingsInRange(
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate fromDate,
            @RequestParam(required = false) @org.springframework.format.annotation.DateTimeFormat(iso = org.springframework.format.annotation.DateTimeFormat.ISO.DATE) java.time.LocalDate toDate,
            @RequestParam(required = false) Long stationId) {
        return bookingService.findMyPartnerBookingsInRange(fromDate, toDate, stationId).stream()
                .map(bookingMapper::toDto)
                .collect(Collectors.toList());
    }

    @PostMapping("/partner/deactivate-seats")
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN', 'ROLE_STATION')")
    public ResponseEntity<Void> deactivateSeats(@RequestBody ManualBlockRequest request) {
        bookingService.deactivateSeatsManually(request);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/trips/{tripId}/passengers")
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN','ROLE_CHAUFFEUR','ROLE_STATION')")
    public List<BookingResponseDTO> getConfirmedPassengers(@PathVariable Long tripId) {
        return bookingService.findConfirmedByTripId(tripId).stream()
                .map(bookingMapper::toDto)
                .collect(Collectors.toList());
    }

    @PostMapping("/partner/offline-sale")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN','ROLE_STATION')")
    public BookingResponseDTO offlineSale(
            @RequestBody @Valid BookingRequestDTO dto,
            org.springframework.security.core.Authentication authentication) {
        Object rawPrincipal = authentication.getPrincipal();
        Long userId;
        if (rawPrincipal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal) {
            // Une gare n'a pas de compte User propre : la vente au guichet est
            // rattachée au dirigeant de la compagnie, comme pour les blocages
            // manuels de sièges (deactivateSeatsManually).
            userId = partnerService.getCurrentPartnerForOperations().getOwner().getId();
        } else {
            User user = userService.findByLogin(authentication.getName());
            userId = user.getId();
        }
        dto.setUserId(userId);
        return bookingMapper.toDto(bookingService.createOfflineSale(dto));
    }
}
