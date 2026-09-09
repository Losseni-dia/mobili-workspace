package com.mobili.backend.module.city.service;

import com.mobili.backend.module.city.entity.City;
import com.mobili.backend.module.city.entity.Country;
import com.mobili.backend.module.city.repository.CityRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Résout un nom de ville saisi (création de gare ou de trajet) vers une {@link City} existante,
 * ou en crée une nouvelle marquée {@code verified=false} si elle n'existe pas encore — jamais de
 * blocage du flux appelant (décision actée : "la gare/le trajet peut être soumis, l'admin affine
 * la géolocalisation et valide ensuite", même logique que l'écran de géocodage des arrêts déjà en
 * place). Aucun géocodage automatique ici : une ville non vérifiée reste sans coordonnées tant que
 * l'écran admin Pays & Villes ne l'a pas traitée.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class CityLookupService {

    private final CityRepository cityRepository;

    @Transactional
    public City resolveOrCreatePending(String name, Country country) {
        String normalized = name.trim();
        return cityRepository.findByNameIgnoreCase(normalized)
                // Repli insensible aux accents avant de créer — sinon "Bouake" (sans accent)
                // recrée un doublon d'une "Bouaké" déjà connue (voir migration V56, doublon
                // constaté en base après un premier dédoublonnage LOWER()-only trop faible).
                .or(() -> cityRepository.findByNormalizedName(normalized))
                .orElseGet(() -> {
                    City city = new City();
                    city.setName(normalized);
                    city.setCountry(country);
                    city.setVerified(false);
                    City saved = cityRepository.save(city);
                    log.info("ℹ️ Nouvelle ville créée en attente de validation admin : '{}' ({})",
                            normalized, country != null ? country.getIsoCode() : "pays inconnu");
                    return saved;
                });
    }
}
