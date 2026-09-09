package com.mobili.backend.module.routing.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.mobili.backend.module.routing.entity.CityLegDuration;

public interface CityLegDurationRepository extends JpaRepository<CityLegDuration, Long> {

    Optional<CityLegDuration> findByFromCityIdAndToCityId(Long fromCityId, Long toCityId);
}
