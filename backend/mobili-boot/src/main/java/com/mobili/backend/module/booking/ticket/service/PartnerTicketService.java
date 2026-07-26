package com.mobili.backend.module.booking.ticket.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.StationPrincipal;
import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.booking.ticket.entity.Ticket;
import com.mobili.backend.module.booking.ticket.repository.TicketRepository;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class PartnerTicketService {

    private final TicketRepository ticketRepository;
    private final PartnerService partenaireService;

    @Transactional(readOnly = true)
    public List<Ticket> findMyTicketsInRange(LocalDate fromDate, LocalDate toDate, Long filterStationId,
            String search) {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        Object rawPrincipal = auth != null ? auth.getPrincipal() : null;
        Partner partner = partenaireService.getCurrentPartnerForOperations();

        LocalDateTime from = fromDate != null ? fromDate.atStartOfDay() : LocalDate.now().minusDays(29).atStartOfDay();
        LocalDateTime to = toDate != null ? toDate.atTime(23, 59, 59) : LocalDateTime.now();

        Long effectiveStationId = filterStationId;
        if (rawPrincipal instanceof StationPrincipal sp) {
            effectiveStationId = sp.getStationId();
        } else if (rawPrincipal instanceof UserPrincipal up && up.getStationId() != null) {
            effectiveStationId = up.getStationId();
        }

        return ticketRepository.findForPartnerList(partner.getId(), effectiveStationId, from, to, search);
    }
}