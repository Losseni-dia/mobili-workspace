package com.mobili.backend.module.city.repository;

import com.mobili.backend.module.city.entity.City;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface CityRepository extends JpaRepository<City, Long> {

    @Query("SELECT c.name FROM City c WHERE LOWER(c.name) LIKE LOWER(CONCAT(:q, '%')) ORDER BY c.name")
    List<String> findByNameStartingWith(@Param("q") String q);

    boolean existsByNameIgnoreCase(String name);
}