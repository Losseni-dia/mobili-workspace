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

import com.mobili.backend.module.booking.booking.dto.BookingRequestDTO;
import com.mobili.backend.module.booking.booking.dto.BookingResponseDTO;
import com.mobili.backend.module.booking.booking.dto.ManualBlockRequest;
import com.mobili.backend.module.booking.booking.dto.mapper.BookingMapper;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/v1/bookings")
public class BookingController {

    private final BookingService bookingService;
    private final BookingMapper bookingMapper;
    private final UserService userService;

    public BookingController(
            BookingService bookingService,
            BookingMapper bookingMapper,
            UserService userService) {
        this.bookingService = bookingService;
        this.bookingMapper = bookingMapper;
        this.userService = userService;
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

    @PatchMapping("/{id}/confirm")
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN')")
    public void confirm(@PathVariable Long id) {
        bookingService.confirmPayment(id);
    }

    @GetMapping("/user/{userId}")
    @PreAuthorize("hasAnyAuthority('ROLE_ADMIN', 'ROLE_PARTNER', 'ROLE_GARE') or #userId == authentication.principal.user.id")
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
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN')")
    public List<BookingResponseDTO> getPartnerBookings() {
        return bookingService.findMyPartnerBookings().stream()
                .map(bookingMapper::toDto)
                .collect(Collectors.toList());
    }

    @PostMapping("/partner/deactivate-seats")
    @PreAuthorize("hasAnyAuthority('ROLE_PARTNER', 'ROLE_GARE', 'ROLE_ADMIN')")
    public ResponseEntity<Void> deactivateSeats(@RequestBody ManualBlockRequest request) {
        bookingService.deactivateSeatsManually(request);
        return ResponseEntity.ok().build();
    }
}
