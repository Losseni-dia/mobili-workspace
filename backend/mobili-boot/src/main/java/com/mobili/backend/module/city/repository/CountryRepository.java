package com.mobili.backend.module.city.repository;

import com.mobili.backend.module.city.entity.Country;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface CountryRepository extends JpaRepository<Country, Long> {

    List<Country> findAllByOrderByNameAsc();

    Optional<Country> findByIsoCode(String isoCode);
}
