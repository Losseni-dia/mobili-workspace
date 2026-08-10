package com.mobili.backend.module.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.mobili.backend.module.pricing.entity.PartnerMonthlyTicketCounter;
import com.mobili.backend.module.pricing.repository.PartnerMonthlyTicketCounterRepository;

@ExtendWith(MockitoExtension.class)
class PartnerMonthlyVolumeServiceTest {

    @Mock
    private PartnerMonthlyTicketCounterRepository repository;

    private PartnerMonthlyVolumeService service;

    @BeforeEach
    void setUp() {
        service = new PartnerMonthlyVolumeService(repository);
    }

    @Test
    void existingCounterAt498_reservingFour_returnsPositions499To502() {
        PartnerMonthlyTicketCounter counter = new PartnerMonthlyTicketCounter();
        counter.setPartnerId(1L);
        counter.setTicketCount(498);
        when(repository.findByPartnerIdAndYearMonthForUpdate(eq(1L), anyString()))
                .thenReturn(Optional.of(counter));
        when(repository.save(any(PartnerMonthlyTicketCounter.class))).thenAnswer(inv -> inv.getArgument(0));

        List<Long> positions = service.reserveNextPositions(1L, 4);

        assertEquals(List.of(499L, 500L, 501L, 502L), positions);
        assertEquals(502, counter.getTicketCount());
    }

    @Test
    void noExistingCounter_createsOneStartingAtZero() {
        when(repository.findByPartnerIdAndYearMonthForUpdate(eq(2L), anyString()))
                .thenReturn(Optional.empty());
        when(repository.save(any(PartnerMonthlyTicketCounter.class))).thenAnswer(inv -> inv.getArgument(0));

        List<Long> positions = service.reserveNextPositions(2L, 3);

        assertEquals(List.of(1L, 2L, 3L), positions);
        // save() appelé une fois pour créer le compteur, une fois pour l'incrément.
        verify(repository, never()).findByPartnerIdAndYearMonthForUpdate(eq(2L), eq(null));
    }

    @Test
    void singleTicket_reservesOnlyOnePosition() {
        PartnerMonthlyTicketCounter counter = new PartnerMonthlyTicketCounter();
        counter.setPartnerId(3L);
        counter.setTicketCount(0);
        when(repository.findByPartnerIdAndYearMonthForUpdate(eq(3L), anyString()))
                .thenReturn(Optional.of(counter));
        when(repository.save(any(PartnerMonthlyTicketCounter.class))).thenAnswer(inv -> inv.getArgument(0));

        List<Long> positions = service.reserveNextPositions(3L, 1);

        assertEquals(List.of(1L), positions);
    }

    // Aucun test de décrémentation n'existe ici : aucune méthode de décrémentation n'existe
    // dans PartnerMonthlyVolumeService (décision ferme — le compteur mensuel n'est jamais
    // décrémenté, même en cas d'annulation).
}
