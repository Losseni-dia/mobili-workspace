package com.mobili.backend.module.pricing.entity;

import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Compteur de tickets vendus par compagnie, par mois calendaire ("2026-08") — une ligne par
 * (partenaire, mois), jamais recréée en cours de mois. Sert de base au barème progressif de
 * commission (voir CompanyCommissionService) : JAMAIS décrémenté (même en cas d'annulation —
 * décision ferme), jamais recalculé rétroactivement si le barème change. La concurrence est
 * gérée par verrou pessimiste applicatif (voir PartnerMonthlyTicketCounterRepository), pas par
 * contrainte SQL — aucun précédent d'optimistic locking (@Version) dans ce projet.
 */
@Entity
@Table(name = "partner_monthly_ticket_counters",
        uniqueConstraints = @UniqueConstraint(columnNames = {"partner_id", "year_month"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class PartnerMonthlyTicketCounter extends AbstractEntity {

    @Column(name = "partner_id", nullable = false)
    private Long partnerId;

    /** Format "yyyy-MM", ex. "2026-08" — YearMonth.toString(). */
    @Column(name = "year_month", nullable = false, length = 7)
    private String yearMonth;

    @Column(name = "ticket_count", nullable = false)
    private Integer ticketCount = 0;
}
