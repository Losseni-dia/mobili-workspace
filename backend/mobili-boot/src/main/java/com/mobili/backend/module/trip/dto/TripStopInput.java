package com.mobili.backend.module.trip.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Un arrêt intermédiaire choisi dans la liste des villes (voir GET /trips/cities/by-country,
 * filtrée sur le pays de la société), ou soumis en texte libre si absent de la liste — même
 * repli "ville introuvable" que StationRequestDTO (voir CityLookupService.resolveOrCreatePending) :
 * la ville est créée en attente de validation admin, jamais bloquant pour la publication du
 * trajet.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TripStopInput {
    private Long cityId;
    private String cityName;
}
