package com.mobili.backend.module.booking.ticket.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
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
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.entity.TicketStatus;
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.trip.entity.Trip;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.trip.service.TripRunService;
import com.mobili.backend.module.trip.service.TripService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.role.Role;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

@ExtendWith(MockitoExtension.class)
class TicketServiceOwnershipTest {

    @Mock
    private TicketRepository ticketRepository;
    @Mock
    private TripService tripService;
    @Mock
    private TripRepository tripRepository;
    @Mock
    private UserService userService;
    @Mock
    private TripRunService tripRunService;
    @Mock
    private InboxNotificationService inboxNotificationService;

    private TicketService ticketService;

    @BeforeEach
    void setUp() {
        ticketService = new TicketService(ticketRepository, tripService, tripRepository, userService, tripRunService,
                inboxNotificationService);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void cancelTicketRejectsNonOwnerUser() {
        Ticket ticket = ticketForPassenger(2L, 200L);
        when(ticketRepository.findById(10L)).thenReturn(Optional.of(ticket));
        authenticate(99L, UserRole.USER);

        MobiliException exception = assertThrows(MobiliException.class, () -> ticketService.cancelTicket(10L));

        assertEquals(MobiliErrorCode.ACCESS_DENIED, exception.getErrorCode());
        verify(ticketRepository, never()).save(ticket);
    }

    @Test
    void cancelTicketAllowsPassengerOwner() {
        Ticket ticket = ticketForPassenger(2L, 200L);
        when(ticketRepository.findById(10L)).thenReturn(Optional.of(ticket));
        authenticate(2L, UserRole.USER);

        ticketService.cancelTicket(10L);

        verify(ticketRepository).save(ticket);
    }

    private Ticket ticketForPassenger(Long passengerId, Long partnerOwnerId) {
        User passenger = new User();
        passenger.setId(passengerId);

        User partnerOwner = new User();
        partnerOwner.setId(partnerOwnerId);
        Partner partner = new Partner();
        partner.setOwner(partnerOwner);
        Trip trip = new Trip();
        trip.setPartner(partner);
        trip.setAvailableSeats(5);

        Ticket ticket = new Ticket();
        ticket.setPassenger(passenger);
        ticket.setTrip(trip);
        ticket.setStatus(TicketStatus.VALIDÉ);
        return ticket;
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
