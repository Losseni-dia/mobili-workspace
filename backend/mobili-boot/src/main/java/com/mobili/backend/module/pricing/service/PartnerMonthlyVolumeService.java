package com.mobili.backend.module.pricing.service;

import com.mobili.backend.module.pricing.entity.PartnerMonthlyTicketCounter;
import com.mobili.backend.module.pricing.repository.PartnerMonthlyTicketCounterRepository;

import lombok.RequiredArgsConstructor;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.YearMonth;
import java.util.List;
import java.util.stream.LongStream;

/**
 * Réservation atomique de positions dans le compteur mensuel de tickets vendus par compagnie
 * — détermine QUELLE position (1-based) chaque ticket d'une réservation occupe dans le
 * compteur cumulé du mois, base du barème progressif (voir CompanyCommissionService).
 *
 * Le compteur ne redémarre jamais en cours de mois et n'est JAMAIS décrémenté (même en cas
 * d'annulation d'un ticket déjà compté — décision ferme, aucune méthode de décrémentation
 * n'existe volontairement ici). Un changement de barème reste non rétroactif par construction :
 * la position déjà attribuée à un ticket ne change jamais après coup.
 *
 * Note : en cas de toute première vente du mois pour une compagnie, deux transactions
 * concurrentes pourraient théoriquement tenter de créer la même ligne de compteur en même
 * temps (contrainte UNIQUE(partner_id, year_month) en filet de sécurité côté DB) — fenêtre de
 * course extrêmement rare (une fois par compagnie par mois), non traitée par retry explicite
 * ici faute de précédent de ce genre ailleurs dans le projet.
 */
@Service
@RequiredArgsConstructor
public class PartnerMonthlyVolumeService {

    private final PartnerMonthlyTicketCounterRepository repository;

    /**
     * Réserve atomiquement {@code count} positions consécutives pour la compagnie, pour le
     * mois calendaire courant, et retourne la liste des positions attribuées (1-based),
     * dans l'ordre. Verrouille la ligne du compteur (PESSIMISTIC_WRITE) le temps de la
     * transaction appelante — nécessaire car une réservation de plusieurs tickets doit occuper
     * une plage contiguë sans qu'une vente concurrente ne s'intercale.
     */
    @Transactional
    public List<Long> reserveNextPositions(Long partnerId, int count) {
        String yearMonth = YearMonth.now().toString();
        PartnerMonthlyTicketCounter counter = repository
                .findByPartnerIdAndYearMonthForUpdate(partnerId, yearMonth)
                .orElseGet(() -> {
                    PartnerMonthlyTicketCounter fresh = new PartnerMonthlyTicketCounter();
                    fresh.setPartnerId(partnerId);
                    fresh.setYearMonth(yearMonth);
                    fresh.setTicketCount(0);
                    return repository.save(fresh);
                });

        long start = counter.getTicketCount();
        counter.setTicketCount((int) (start + count));
        repository.save(counter);

        return LongStream.rangeClosed(start + 1, start + count).boxed().toList();
    }
}
