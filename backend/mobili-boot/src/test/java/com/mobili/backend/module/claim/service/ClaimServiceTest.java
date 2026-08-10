package com.mobili.backend.module.claim.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.service.BookingService;
import com.mobili.backend.module.claim.dto.ClaimResponse;
import com.mobili.backend.module.claim.dto.CreateClaimRequest;
import com.mobili.backend.module.claim.entity.Claim;
import com.mobili.backend.module.claim.enums.ClaimReason;
import com.mobili.backend.module.claim.enums.ClaimStatus;
import com.mobili.backend.module.claim.repository.ClaimRepository;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

@ExtendWith(MockitoExtension.class)
class ClaimServiceTest {

    @Mock
    private ClaimRepository claimRepository;
    @Mock
    private UserService userService;
    @Mock
    private BookingService bookingService;

    private ClaimService claimService;

    @BeforeEach
    void setUp() {
        claimService = new ClaimService(claimRepository, userService, bookingService);
    }

    @Test
    void createClaim_bookingRequiredReason_withoutBookingId_rejectsCleanlyWith400() {
        CreateClaimRequest request = new CreateClaimRequest(
                ClaimReason.REFUND_REQUEST, null, "Je veux être remboursé", null);

        MobiliException ex = assertThrows(MobiliException.class,
                () -> claimService.createClaim(1L, request));

        assertEquals(MobiliErrorCode.VALIDATION_ERROR, ex.getErrorCode());
        assertNotNull(ex.getMessage());
        verify(bookingService, never()).findById(any());
        verify(claimRepository, never()).save(any());
    }

    @Test
    void createClaim_bookingRequiredReason_withBookingId_savesLinkedBooking() {
        User user = new User();
        user.setId(1L);
        when(userService.findById(1L)).thenReturn(user);

        Booking booking = pendingBooking();
        when(bookingService.findById(42L)).thenReturn(booking);
        when(claimRepository.save(any(Claim.class))).thenAnswer(inv -> inv.getArgument(0));

        CreateClaimRequest request = new CreateClaimRequest(
                ClaimReason.CANCELLATION, 42L, "Je veux annuler ma réservation", null);

        ClaimResponse response = claimService.createClaim(1L, request);

        assertEquals(ClaimStatus.RECEIVED, response.status());
        assertNotNull(response.booking());
        assertEquals(42L, response.booking().bookingId());
    }

    @Test
    void createClaim_reasonWithoutBookingRequirement_allowsNullBookingId() {
        User user = new User();
        user.setId(1L);
        when(userService.findById(1L)).thenReturn(user);
        when(claimRepository.save(any(Claim.class))).thenAnswer(inv -> inv.getArgument(0));

        CreateClaimRequest request = new CreateClaimRequest(
                ClaimReason.LOST_ITEM, null, "J'ai oublié mon sac dans le bus",
                Map.of("lostItemDescription", "Sac à dos noir"));

        ClaimResponse response = claimService.createClaim(1L, request);

        assertNull(response.booking());
        assertEquals("Sac à dos noir", response.details().get("lostItemDescription"));
        verify(bookingService, never()).findById(any());
    }

    @Test
    void createClaim_blankMessage_rejectedWithValidationError() {
        CreateClaimRequest request = new CreateClaimRequest(ClaimReason.OTHER, null, "   ", null);

        MobiliException ex = assertThrows(MobiliException.class,
                () -> claimService.createClaim(1L, request));

        assertEquals(MobiliErrorCode.VALIDATION_ERROR, ex.getErrorCode());
    }

    @Test
    void updateStatus_toResolved_setsResolvedAt() {
        Claim claim = new Claim();
        claim.setStatus(ClaimStatus.IN_PROGRESS);
        when(claimRepository.findById(5L)).thenReturn(Optional.of(claim));
        when(claimRepository.save(any(Claim.class))).thenAnswer(inv -> inv.getArgument(0));

        ClaimResponse response = claimService.updateStatus(5L, ClaimStatus.RESOLVED, "Remboursé");

        assertEquals(ClaimStatus.RESOLVED, response.status());
        assertNotNull(response.resolvedAt());
        assertEquals("Remboursé", response.adminNote());
    }

    @Test
    void updateStatus_toInProgress_doesNotSetResolvedAt() {
        Claim claim = new Claim();
        claim.setStatus(ClaimStatus.RECEIVED);
        when(claimRepository.findById(5L)).thenReturn(Optional.of(claim));
        when(claimRepository.save(any(Claim.class))).thenAnswer(inv -> inv.getArgument(0));

        ClaimResponse response = claimService.updateStatus(5L, ClaimStatus.IN_PROGRESS, null);

        assertNull(response.resolvedAt());
    }

    @Test
    void updateStatus_unknownId_throwsNotFound() {
        when(claimRepository.findById(99L)).thenReturn(Optional.empty());

        MobiliException ex = assertThrows(MobiliException.class,
                () -> claimService.updateStatus(99L, ClaimStatus.RESOLVED, null));

        assertEquals(MobiliErrorCode.RESOURCE_NOT_FOUND, ex.getErrorCode());
    }

    @Test
    void listClaims_withStatusFilter_delegatesToRepository() {
        when(claimRepository.findByStatusOrderByCreatedAtDesc(ClaimStatus.RECEIVED))
                .thenReturn(List.of(new Claim()));

        List<ClaimResponse> result = claimService.listClaims(ClaimStatus.RECEIVED);

        assertEquals(1, result.size());
    }

    @Test
    void listClaims_withoutFilter_returnsAll() {
        when(claimRepository.findAllByOrderByCreatedAtDesc()).thenReturn(List.of(new Claim(), new Claim()));

        List<ClaimResponse> result = claimService.listClaims(null);

        assertEquals(2, result.size());
    }

    private Booking pendingBooking() {
        Trip trip = new Trip();
        trip.setDepartureCity("Abidjan");
        trip.setArrivalCity("Bouaké");

        Booking booking = new Booking();
        booking.setId(42L);
        booking.setReference("RESERVATION-42");
        booking.setTrip(trip);
        booking.setTotalPrice(10_000d);
        return booking;
    }
}
