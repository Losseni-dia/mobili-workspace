package com.mobili.backend.module.city.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "cities")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class City {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String name;

    /** Remplace l'ancien champ String "country" (toujours "CI" en dur, jamais réellement
     *  renseigné) — nullable pendant la transition (villes existantes pas encore rattachées, voir
     *  script de backfill Côte d'Ivoire par défaut). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "country_id")
    private Country country;

    /** Mêmes conventions que TripStop.latitude/longitude — nullable tant que la ville n'a pas été
     *  géocodée (écran admin Pays & Villes, même mécanisme que le géocodage des arrêts). */
    private Double latitude;
    private Double longitude;

    /** false = créée à la volée par un partenaire (trajet ou gare avec une ville absente de la
     *  liste proposée) et pas encore contrôlée par un admin — voir écran admin Pays & Villes,
     *  qui liste en priorité les villes non vérifiées pour validation/correction du géocodage. */
    @Column(nullable = false)
    private boolean verified = false;
}
