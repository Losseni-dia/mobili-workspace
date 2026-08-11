package com.mobili.backend.module.pricing.repository;

import com.mobili.backend.module.pricing.entity.PartnerMonthlyTicketCounter;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface PartnerMonthlyTicketCounterRepository extends JpaRepository<PartnerMonthlyTicketCounter, Long> {

    /**
     * Verrou pessimiste (SELECT ... FOR UPDATE) : nécessaire pour réserver atomiquement une
     * PLAGE de positions (ex. 4 tickets d'une même réservation) sans perte de mise à jour en
     * cas de ventes concurrentes pour la même compagnie — un simple retry optimiste ne suffit
     * pas ici, l'exclusion mutuelle doit tenir pendant toute la durée de la transaction
     * appelante (voir PartnerMonthlyVolumeService.reserveNextPositions).
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT c FROM PartnerMonthlyTicketCounter c WHERE c.partnerId = :partnerId AND c.yearMonth = :yearMonth")
    Optional<PartnerMonthlyTicketCounter> findByPartnerIdAndYearMonthForUpdate(
            @Param("partnerId") Long partnerId, @Param("yearMonth") String yearMonth);
}
