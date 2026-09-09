package com.mobili.backend.module.routing.entity;

import java.time.LocalDateTime;

import com.mobili.backend.module.city.entity.City;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Durée de trajet (Mapbox/Google Directions) mise en cache pour une paire de villes — évite de
 * refacturer un appel Directions à chaque création/modification de trajet pour un tronçon déjà
 * calculé (les mêmes paires de villes reviennent sur de nombreux trajets/éditions). Voir
 * TripStopSyncService.legDurationMinutes : un trajet Abidjan→Yamoussoukro n'appelle l'API qu'une
 * seule fois, tous les trajets/éditions suivants sur ce tronçon réutilisent l'entrée en cache
 * jusqu'à expiration (STALE_AFTER).
 */
@Entity
@Table(name = "city_leg_durations",
        uniqueConstraints = @UniqueConstraint(columnNames = {"from_city_id", "to_city_id"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CityLegDuration extends AbstractEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "from_city_id", nullable = false)
    private City fromCity;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "to_city_id", nullable = false)
    private City toCity;

    @Column(name = "duration_seconds", nullable = false)
    private long durationSeconds;

    @Column(name = "distance_meters")
    private Double distanceMeters;

    /** Date du dernier calcul réel (Mapbox/Google) — distinct de {@code createdAt} (non
     *  modifiable) : mis à jour à chaque rafraîchissement au-delà de STALE_AFTER. */
    @Column(name = "computed_at", nullable = false)
    private LocalDateTime computedAt;
}
