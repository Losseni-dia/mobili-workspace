package com.mobili.backend.module.tracking.service;

import com.google.firebase.auth.FirebaseAuth;

import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.entity.BookingStatus;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.entity.TripStatus;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.MockedStatic;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Couvre l'autorisation (garde métier avant tout appel Firebase) — pas de repository mocké pour
 * TripService (mocké directement, findById suffit). FirebaseAuth est un singleton statique :
 * mockStatic (Mockito inline mock maker, déjà utilisé ailleurs dans ce projet — voir le warning
 * "self-attaching" affiché par les autres suites de tests) permet de couvrir aussi le chemin
 * nominal sans dépendre d'un vrai FirebaseApp initialisé (absent en test, aucun fichier de
 * credentials fourni).
 */
@ExtendWith(MockitoExtension.class)
class LiveTrackingTokenServiceTest {

    private final TripService tripService = mock(TripService.class);
    private final BookingRepository bookingRepository = mock(BookingRepository.class);
    private final LiveTrackingTokenService service = new LiveTrackingTokenService(tripService, bookingRepository);

    private Trip trip(TripStatus status) {
        Trip trip = new Trip();
        trip.setId(1L);
        trip.setStatus(status);
        return trip;
    }

    private Booking booking(Long customerId, BookingStatus status) {
        Booking booking = new Booking();
        User customer = new User();
        customer.setId(customerId);
        booking.setCustomer(customer);
        booking.setStatus(status);
        return booking;
    }

    @Test
    void mintPassengerToken_tripNotInProgress_throwsAccessDenied() {
        when(tripService.findById(1L)).thenReturn(trip(TripStatus.PROGRAMMÉ));

        assertThrows(MobiliException.class, () -> service.mintPassengerToken(1L, 42L));
    }

    @Test
    void mintPassengerToken_noActiveBooking_throwsAccessDenied() {
        when(tripService.findById(1L)).thenReturn(trip(TripStatus.EN_COURS));
        when(bookingRepository.findByTripId(1L)).thenReturn(List.of(
                booking(42L, BookingStatus.CANCELLED),
                booking(99L, BookingStatus.CONFIRMED)));

        assertThrows(MobiliException.class, () -> service.mintPassengerToken(1L, 42L));
    }

    @Test
    void mintPassengerToken_activeConfirmedBooking_mintsToken() throws com.google.firebase.auth.FirebaseAuthException {
        when(tripService.findById(1L)).thenReturn(trip(TripStatus.EN_COURS));
        when(bookingRepository.findByTripId(1L)).thenReturn(List.of(booking(42L, BookingStatus.CONFIRMED)));

        try (MockedStatic<FirebaseAuth> firebaseAuthStatic = Mockito.mockStatic(FirebaseAuth.class)) {
            FirebaseAuth mockAuth = mock(FirebaseAuth.class);
            firebaseAuthStatic.when(FirebaseAuth::getInstance).thenReturn(mockAuth);
            when(mockAuth.createCustomToken(anyString(), any())).thenReturn("fake-token");

            String token = service.mintPassengerToken(1L, 42L);

            assertEquals("fake-token", token);
        }
    }

    @Test
    void mintPassengerToken_activeOfflineSaleBooking_mintsToken() throws com.google.firebase.auth.FirebaseAuthException {
        when(tripService.findById(1L)).thenReturn(trip(TripStatus.EN_COURS));
        when(bookingRepository.findByTripId(1L)).thenReturn(List.of(booking(42L, BookingStatus.OFFLINE_SALE)));

        try (MockedStatic<FirebaseAuth> firebaseAuthStatic = Mockito.mockStatic(FirebaseAuth.class)) {
            FirebaseAuth mockAuth = mock(FirebaseAuth.class);
            firebaseAuthStatic.when(FirebaseAuth::getInstance).thenReturn(mockAuth);
            when(mockAuth.createCustomToken(anyString(), any())).thenReturn("fake-token");

            String token = service.mintPassengerToken(1L, 42L);

            assertEquals("fake-token", token);
        }
    }

    @Test
    void mintDriverToken_mintsToken() throws com.google.firebase.auth.FirebaseAuthException {
        try (MockedStatic<FirebaseAuth> firebaseAuthStatic = Mockito.mockStatic(FirebaseAuth.class)) {
            FirebaseAuth mockAuth = mock(FirebaseAuth.class);
            firebaseAuthStatic.when(FirebaseAuth::getInstance).thenReturn(mockAuth);
            when(mockAuth.createCustomToken(anyString(), any())).thenReturn("driver-token");

            String token = service.mintDriverToken(1L, 7L);

            assertEquals("driver-token", token);
        }
    }
}
