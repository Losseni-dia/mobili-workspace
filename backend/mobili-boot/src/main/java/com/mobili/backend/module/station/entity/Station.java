package com.mobili.backend.module.station.entity;

import com.mobili.backend.module.city.entity.City;
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

    /** Ville de la gare — choisie dans la liste gérée (voir CityLookupService pour le cas
     *  "ville introuvable"), toujours dans le même pays que la société propriétaire (voir
     *  StationService.create). Nullable pendant la transition (gares déjà existantes, voir
     *  script de backfill Côte d'Ivoire par défaut). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "city_id")
    private City city;

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