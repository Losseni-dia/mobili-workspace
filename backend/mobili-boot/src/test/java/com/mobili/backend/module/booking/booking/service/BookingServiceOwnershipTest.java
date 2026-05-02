package com.mobili.backend.module.booking.booking.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.Set;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.booking.booking.entity.Booking;
import com.mobili.backend.module.booking.booking.repository.BookingRepository;
import com.mobili.backend.module.booking.ticket.service.TicketService;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.service.TripPricingService;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.Role;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

@ExtendWith(MockitoExtension.class)
class BookingServiceOwnershipTest {

    @Mock
    private BookingRepository bookingRepository;
    @Mock
    private TripService tripService;
    @Mock
    private TripRepository tripRepository;
    @Mock
    private UserService userService;
    @Mock
    private TicketService ticketService;
    @Mock
    private UserRepository userRepository;
    @Mock
    private PartnerService partnerService;
    @Mock
    private TripRunService tripRunService;
    @Mock
    private TripPricingService tripPricingService;
    @Mock
    private AnalyticsEventService analyticsEventService;
    @Mock
    private InboxNotificationService inboxNotificationService;

    private BookingService bookingService;

    @BeforeEach
    void setUp() {
        bookingService = new BookingService(
                bookingRepository,
                tripService,
                tripRepository,
                userService,
                ticketService,
                userRepository,
                partnerService,
                tripRunService,
                tripPricingService,
                analyticsEventService,
                inboxNotificationService);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void findByIdRejectsNonOwnerUser() {
        Booking booking = bookingForUser(2L);
        when(bookingRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(booking));
        authenticate(99L, UserRole.USER);

        MobiliException exception = assertThrows(MobiliException.class, () -> bookingService.findById(1L));

        assertEquals(MobiliErrorCode.ACCESS_DENIED, exception.getErrorCode());
    }

    @Test
    void findByIdAllowsOwnerUser() {
        Booking booking = bookingForUser(2L);
        when(bookingRepository.findByIdWithDetails(1L)).thenReturn(Optional.of(booking));
        authenticate(2L, UserRole.USER);

        Booking found = bookingService.findById(1L);

        assertNotNull(found);
        assertEquals(2L, found.getCustomer().getId());
    }

    private Booking bookingForUser(Long customerId) {
        User customer = new User();
        customer.setId(customerId);

        User partnerOwner = new User();
        partnerOwner.setId(100L);
        Partner partner = new Partner();
        partner.setOwner(partnerOwner);
        Trip trip = new Trip();
        trip.setPartner(partner);

        Booking booking = new Booking();
        booking.setCustomer(customer);
        booking.setTrip(trip);
        return booking;
    }

    private void authenticate(Long userId, UserRole role) {
        User user = new User();
        user.setId(userId);
        user.setLogin("user-" + userId);
        user.setPassword("pwd");

        Role roleEntity = new Role();
        roleEntity.setName(role);
        user.setRoles(Set.of(roleEntity));

        UserPrincipal principal = UserPrincipal.fromUser(user);
        UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                principal,
                null,
                principal.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(authentication);
    }
}
