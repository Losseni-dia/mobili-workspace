package com.mobili.backend.module.city.dto;

/** Une entrée de la liste des pays — pour les `<select>` des écrans admin Pays & Villes et des
 *  formulaires société/gare (inscription partenaire, création de gare). Dans module.city.dto
 *  (plutôt que module.admin.dto) car ce n'est pas un DTO réservé à l'admin : exposé aussi via
 *  l'endpoint public GET /trips/countries. */
public record CountryOption(Long id, String name, String isoCode, String continent) {
}
