package com.mobili.backend.module.trip.dto;

import java.time.LocalDateTime;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TripStopResponseDTO {
    private int stopIndex;
    private String cityLabel;
    private LocalDateTime plannedDepartureAt;
    /** Null tant que l'arrêt n'a pas été géocodé (voir écran admin de géocodage) — utilisées
     *  côté mobilipro pour l'arrivée/départ automatique par géofence (aucun géofence posé si
     *  absentes, fallback silencieux sur le bouton manuel pour cet arrêt). */
    private Double latitude;
    private Double longitude;
}
