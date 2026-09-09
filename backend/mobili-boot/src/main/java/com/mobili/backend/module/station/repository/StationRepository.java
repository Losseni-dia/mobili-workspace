package com.mobili.backend.module.station.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.mobili.backend.module.station.entity.Station;

@Repository
public interface StationRepository extends JpaRepository<Station, Long> {

    // city est désormais une entité (City) : navigation imbriquée city.name pour trier — voir
    // https://docs.spring.io/spring-data/jpa/reference/repositories/query-methods-details.html
    List<Station> findByPartnerIdOrderByCity_NameAscNameAsc(Long partnerId);

    Optional<Station> findByIdAndPartnerId(Long id, Long partnerId);

    long countByPartnerId(Long partnerId);

    boolean existsByPartnerIdAndCode(Long partnerId, String code);

    /** uk_stations_code (migration V24) est une contrainte unique GLOBALE, pas par société —
     *  generateUniqueStationCode doit vérifier l'unicité globale, pas juste par partenaire, sous
     *  peine de 409 générique si deux sociétés différentes tirent le même code aléatoire. */
    boolean existsByCode(String code);

    Optional<Station> findByCode(String code);
}
