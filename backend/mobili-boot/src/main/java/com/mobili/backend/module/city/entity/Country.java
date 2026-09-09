package com.mobili.backend.module.city.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Table de référence des pays — remplace la chaîne morte {@code City.country} (toujours "CI" par
 * défaut, jamais réellement renseignée). Seedée une fois via script SQL (~98 pays Afrique +
 * Europe, repris de la liste déjà curatée côté écran de géocodage —
 * frontend admin-geocoding.ts / mobilipro admin_geocoding_page.dart), pas de CRUD de création
 * libre : la liste des pays est fixe, seul l'écran admin Pays & Villes permet de la consulter.
 */
@Entity
@Table(name = "countries")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class Country {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String name;

    /** ISO 3166-1 alpha-2 (ex. "CI", "FR") — utilisé pour restreindre les recherches Mapbox
     *  Geocoding (voir MapboxGeocodingService.geocode(query, countryCode)). */
    @Column(name = "iso_code", nullable = false, unique = true, length = 2)
    private String isoCode;

    /** "Afrique" / "Europe" — pour le regroupement <optgroup> déjà utilisé côté écran de
     *  géocodage, repris ici pour le nouvel écran admin Pays & Villes. */
    private String continent;
}
