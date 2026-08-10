package com.mobili.backend.module.claim.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
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
import com.mobili.backend.module.claim.dto.PassengerClaimResponse;
import com.mobili.backend.module.claim.entity.Claim;
import com.mobili.backend.module.claim.enums.ClaimReason;
import com.mobili.backend.module.claim.enums.ClaimStatus;
import com.mobili.backend.module.claim.repository.ClaimRepository;
import com.mobili.backend.module.notification.entity.MobiliNotificationType;
import com.mobili.backend.module.notification.service.InboxNotificationService;
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
    @Mock
    private InboxNotificationService inboxNotificationService;

    private ClaimService claimService;

    @BeforeEach
    void setUp() {
        claimService = new ClaimService(claimRepository, userService, bookingService, inboxNotificationService);
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
        verify(inboxNotificationService, never()).notifyAdmins(anyString(), anyString(), any(), any(Claim.class));
    }

    @Test
    void createClaim_bookingRequiredReason_withBookingId_savesLinkedBookingAndNotifiesAdmins() {
        User user = new User();
        user.setId(1L);
        when(userService.findById(1L)).thenReturn(user);

        Booking booking = pendingBooking();
        when(bookingService.findById(42L)).thenReturn(booking);
        when(claimRepository.save(any(Claim.class))).thenAnswer(inv -> inv.getArgument(0));

        CreateClaimRequest request = new CreateClaimRequest(
                ClaimReason.CANCELLATION, 42L, "Je veux annuler ma réservation", null);

        PassengerClaimResponse response = claimService.createClaim(1L, request);

        assertEquals(ClaimStatus.RECEIVED, response.status());
        assertNotNull(response.booking());
        assertEquals(42L, response.booking().bookingId());
        verify(inboxNotificationService).notifyAdmins(
                anyString(), anyString(), eq(MobiliNotificationType.CLAIM_SUBMITTED), any(Claim.class));
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

        PassengerClaimResponse response = claimService.createClaim(1L, request);

        assertNull(response.booking());
        assertEquals("Sac à dos noir", response.details().get("lostItemDescription"));
        verify(bookingService, never()).findById(any());
        verify(inboxNotificationService).notifyAdmins(
                anyString(), anyString(), eq(MobiliNotificationType.CLAIM_SUBMITTED), any(Claim.class));
    }

    @Test
    void createClaim_blankMessage_rejectedWithValidationError() {
        CreateClaimRequest request = new CreateClaimRequest(ClaimReason.OTHER, null, "   ", null);

        MobiliException ex = assertThrows(MobiliException.class,
                () -> claimService.createClaim(1L, request));

        assertEquals(MobiliErrorCode.VALIDATION_ERROR, ex.getErrorCode());
        verify(inboxNotificationService, never()).notifyAdmins(anyString(), anyString(), any(), any(Claim.class));
    }

    @Test
    void updateStatus_toResolved_setsResolvedAtAndNotifiesUserWithResolutionMessage() {
        User user = new User();
        user.setId(7L);
        Claim claim = new Claim();
        claim.setUser(user);
        claim.setStatus(ClaimStatus.IN_PROGRESS);
        when(claimRepository.findById(5L)).thenReturn(Optional.of(claim));
        when(claimRepository.save(any(Claim.class))).thenAnswer(inv -> inv.getArgument(0));

        ClaimResponse response = claimService.updateStatus(
                5L, ClaimStatus.RESOLVED, "Remboursé", "Votre remboursement a été effectué.");

        assertEquals(ClaimStatus.RESOLVED, response.status());
        assertNotNull(response.resolvedAt());
        assertEquals("Remboursé", response.adminNote());
        assertEquals("Votre remboursement a été effectué.", response.resolutionMessage());
        verify(inboxNotificationService).notifyUser(
                eq(user),
                anyString(),
                eq("Votre remboursement a été effectué."),
                eq(MobiliNotificationType.CLAIM_STATUS_UPDATED),
                any(Claim.class));
    }

    @Test
    void updateStatus_toRejected_withoutResolutionMessage_notifiesWithDefaultMessage() {
        User user = new User();
        user.setId(7L);
        Claim claim = new Claim();
        claim.setUser(user);
        claim.setStatus(ClaimStatus.RECEIVED);
        when(claimRepository.findById(5L)).thenReturn(Optional.of(claim));
        when(claimRepository.save(any(Claim.class))).thenAnswer(inv -> inv.getArgument(0));

        ClaimResponse response = claimService.updateStatus(5L, ClaimStatus.REJECTED, null, null);

        assertEquals(ClaimStatus.REJECTED, response.status());
        assertNull(response.resolutionMessage());
        verify(inboxNotificationService).notifyUser(
                eq(user), anyString(), anyString(), eq(MobiliNotificationType.CLAIM_STATUS_UPDATED), any(Claim.class));
    }

    @Test
    void updateStatus_toInProgress_doesNotSetResolvedAtAndDoesNotNotify() {
        Claim claim = new Claim();
        claim.setStatus(ClaimStatus.RECEIVED);
        when(claimRepository.findById(5L)).thenReturn(Optional.of(claim));
        when(claimRepository.save(any(Claim.class))).thenAnswer(inv -> inv.getArgument(0));

        ClaimResponse response = claimService.updateStatus(5L, ClaimStatus.IN_PROGRESS, null, null);

        assertNull(response.resolvedAt());
        verify(inboxNotificationService, never()).notifyUser(any(), anyString(), anyString(), any(), any(Claim.class));
    }

    @Test
    void updateStatus_unknownId_throwsNotFound() {
        when(claimRepository.findById(99L)).thenReturn(Optional.empty());

        MobiliException ex = assertThrows(MobiliException.class,
                () -> claimService.updateStatus(99L, ClaimStatus.RESOLVED, null, null));

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
