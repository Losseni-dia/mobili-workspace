package com.mobili.backend.module.booking.ticket.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.booking.ticket.dto.TicketRequestDTO;
import com.mobili.backend.module.booking.ticket.dto.TicketResponseDTO;
import com.mobili.backend.module.booking.ticket.dto.mapper.TicketMapper;
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.service.TicketService;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/v1/tickets")
@RequiredArgsConstructor
public class TicketController {

    private final TicketService ticketService;
    private final TicketMapper ticketMapper;

    // ACHETER / RÉSERVER UN TICKET
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyAuthority('ROLE_USER', 'ROLE_PARTNER', 'ROLE_ADMIN')")
    public TicketResponseDTO create(
            @RequestBody @Valid TicketRequestDTO dto,
            @AuthenticationPrincipal UserPrincipal principal) {
        Long authenticatedUserId = principal.getUser().getId();
        Ticket ticket = ticketService.create(dto.getTripId(), authenticatedUserId);

        // Le controller transforme l'entité en DTO pour la réponse
        return ticketMapper.toDto(ticket);
    }

    // VOIR L'HISTORIQUE DES TICKETS D'UN UTILISATEUR
    @GetMapping("/user/{userId}")
    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyAuthority('ROLE_ADMIN', 'ROLE_PARTNER') or #userId == authentication.principal.user.id")
    public List<TicketResponseDTO> getUserTickets(@PathVariable Long userId) {
        return ticketService.findAllByUserId(userId).stream()
                .map(ticketMapper::toDto)
                .collect(Collectors.toList());
    }

    // ANNULER UN TICKET
    @PatchMapping("/{id}/cancel")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("isAuthenticated()")
    public void cancel(@PathVariable Long id) {
        ticketService.cancelTicket(id);
    }

    @PatchMapping("/verify/{ticketNumber}")
    @PreAuthorize("hasAnyAuthority('ROLE_CHAUFFEUR', 'ROLE_GARE', 'ROLE_ADMIN')")
    public TicketResponseDTO verifyTicket(@PathVariable String ticketNumber) {
        // Le service traite la logique et change le statut
        Ticket ticket = ticketService.verifyAndUseTicket(ticketNumber);

        // On renvoie le DTO pour que le contrôleur voie le nom du passager sur son
        // écran
        return ticketMapper.toDto(ticket);
    }

}