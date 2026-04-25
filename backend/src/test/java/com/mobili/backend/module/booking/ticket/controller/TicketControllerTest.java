package com.mobili.backend.module.booking.ticket.controller;

import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.booking.ticket.dto.TicketRequestDTO;
import com.mobili.backend.module.booking.ticket.dto.TicketResponseDTO;
import com.mobili.backend.module.booking.ticket.dto.mapper.TicketMapper;
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.service.TicketService;
import com.mobili.backend.module.user.entity.User;

@ExtendWith(MockitoExtension.class)
class TicketControllerTest {

    @Mock
    private TicketService ticketService;
    @Mock
    private TicketMapper ticketMapper;

    private TicketController ticketController;

    @BeforeEach
    void setUp() {
        ticketController = new TicketController(ticketService, ticketMapper);
    }

    @Test
    void createUsesAuthenticatedUserIdInsteadOfRequestUserId() {
        TicketRequestDTO request = new TicketRequestDTO();
        request.setTripId(42L);
        request.setUserId(999L);

        User user = new User();
        user.setId(7L);
        user.setLogin("john");
        user.setPassword("pwd");
        UserPrincipal principal = UserPrincipal.fromUser(user);

        Ticket ticket = new Ticket();
        TicketResponseDTO response = new TicketResponseDTO();
        when(ticketService.create(eq(42L), eq(7L))).thenReturn(ticket);
        when(ticketMapper.toDto(ticket)).thenReturn(response);

        TicketResponseDTO result = ticketController.create(request, principal);

        verify(ticketService).create(42L, 7L);
        assertSame(response, result);
    }
}
