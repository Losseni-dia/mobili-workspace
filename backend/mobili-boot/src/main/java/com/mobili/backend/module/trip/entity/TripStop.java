package com.mobili.backend.module.trip.entity;

import java.time.LocalDateTime;

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
@Table(name = "trip_stops")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class TripStop extends AbstractEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "trip_id", nullable = false)
    private Trip trip;

    @Column(name = "stop_index", nullable = false)
    private int stopIndex;

    @Column(name = "city_label", nullable = false, length = 120)
    private String cityLabel;

    /** Heure planifiée de départ du car depuis cet arrêt (cut-off vente embarquement ici). */
    @Column(name = "planned_departure_at", nullable = false)
    private LocalDateTime plannedDepartureAt;

    /**
     * Coordonnées GPS de cet arrêt — nullable, renseignées manuellement (pas d'interface de
     * saisie). Un arrêt sans coordonnées rend le calcul d'ETA (module routing) indisponible pour
     * ce trajet, jamais une estimation approximative basée sur un centre-ville par défaut.
     */
    @Column(name = "latitude")
    private Double latitude;

    @Column(name = "longitude")
    private Double longitude;
}
