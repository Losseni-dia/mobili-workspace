package com.mobili.backend.module.station.entity;

import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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

    /**
     * Code interne unique par partenaire (généré automatiquement, ex. GAR-AB12F).
     */
    @Column(name = "code")
    private String code;
    @Column(nullable = false)
    private boolean active = true;

    /**
     * Mot de passe (hashé) permettant à la gare de se connecter via son code comme
     * identifiant.
     */
    @Column(name = "password")
    private String password;

    @Column(name = "fcm_token", length = 500)
    private String fcmToken;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "partner_id", nullable = false)
    private Partner partner;
}