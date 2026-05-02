package com.mobili.backend.module.station.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.mobili.backend.module.station.entity.Station;

@Repository
public interface StationRepository extends JpaRepository<Station, Long> {

    List<Station> findByPartnerIdOrderByCityAscNameAsc(Long partnerId);

    Optional<Station> findByIdAndPartnerId(Long id, Long partnerId);

    long countByPartnerId(Long partnerId);

    boolean existsByPartnerIdAndCode(Long partnerId, String code);
}
