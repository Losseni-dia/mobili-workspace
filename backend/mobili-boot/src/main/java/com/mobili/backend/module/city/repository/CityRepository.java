package com.mobili.backend.module.city.repository;

import com.mobili.backend.module.city.entity.City;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface CityRepository extends JpaRepository<City, Long> {

    @Query("SELECT c.name FROM City c WHERE LOWER(c.name) LIKE LOWER(CONCAT(:q, '%')) ORDER BY c.name")
    List<String> findByNameStartingWith(@Param("q") String q);

    /** Même filtre que findByNameStartingWith, mais restreint à un pays — utilisé par le
     *  sélecteur de ville des gares (une gare ne peut être que dans le pays de sa société). */
    @Query("SELECT c FROM City c WHERE c.country.id = :countryId "
            + "AND LOWER(c.name) LIKE LOWER(CONCAT(:q, '%')) ORDER BY c.name")
    List<City> findByCountryIdAndNameStartingWith(@Param("countryId") Long countryId, @Param("q") String q);

    List<City> findAllByOrderByNameAsc();

    /** Villes pas encore contrôlées par un admin (créées à la volée via le flux "ville
     *  introuvable" — trajet ou gare) — cible de l'écran admin Pays & Villes. */
    List<City> findByVerifiedFalseOrderByName();

    boolean existsByNameIgnoreCase(String name);

    Optional<City> findByNameIgnoreCase(String name);
}