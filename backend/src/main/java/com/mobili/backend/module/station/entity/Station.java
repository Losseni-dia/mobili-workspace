package com.mobili.backend.module.station.entity;

import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "stations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Station extends AbstractEntity {

    @Column(nullable = false)
    private String name;

    /** Ville / localisation (affichage, filtres) */
    @Column(nullable = false)
    private String city;

    /** Code interne unique par partenaire (généré automatiquement, ex. GAR-AB12F). */
    @Column(name = "code")
    private String code;

    @Enumerated(EnumType.STRING)
    @Column(name = "approval_status", length = 20)
    private StationApprovalStatus approvalStatus;

    @Column(nullable = false)
    private boolean active = true;

    /**
     * {@code false} à la création : aucune action gare / trajet tant que le dirigeant
     * n'a pas approuvé la gare. Passe à {@code true} dans {@code approve}.
     * Nullable pour les lignes existantes (rétrocompat) : on déduit alors du reste.
     */
    @Column(name = "validated")
    private Boolean validated;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "partner_id", nullable = false)
    private Partner partner;
}
