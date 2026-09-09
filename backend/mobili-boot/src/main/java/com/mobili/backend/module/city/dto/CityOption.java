package com.mobili.backend.module.city.dto;

/** Une entrée de la liste des villes filtrée par pays — pour l'autocomplétion des formulaires
 *  gare/trajet (GET /trips/cities/by-country). latitude/longitude peuvent être nulles (ville pas
 *  encore géocodée par un admin, voir CityLookupService/écran admin Pays & Villes) mais restent
 *  sélectionnables : la géoloc est complétée plus tard, sans bloquer le partenaire. */
public record CityOption(Long id, String name, Double latitude, Double longitude, boolean verified) {
}
