package com.mobili.backend.module.trip.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.mobili.backend.module.trip.entity.TripStop;

public interface TripStopRepository extends JpaRepository<TripStop, Long> {

    List<TripStop> findByTripIdOrderByStopIndexAsc(Long tripId);

    /** Utilisé par l'écran admin de géocodage — un city_label peut apparaître sur plusieurs
     *  trajets, on ne veut géocoder chaque nom qu'une seule fois. */
    @Query("SELECT DISTINCT ts.cityLabel FROM TripStop ts "
            + "WHERE ts.latitude IS NULL OR ts.longitude IS NULL ORDER BY ts.cityLabel")
    List<String> findDistinctCityLabelsMissingCoordinates();

    /** Applique une coordonnée à TOUS les arrêts portant ce city_label (variantes déjà
     *  regroupées côté admin avant l'appel) — jamais une estimation, seulement ce que l'admin
     *  a explicitement validé à l'écran de prévisualisation. */
    @Modifying
    @Query("UPDATE TripStop ts SET ts.latitude = :latitude, ts.longitude = :longitude "
            + "WHERE ts.cityLabel = :cityLabel")
    int updateCoordinatesByCityLabel(
            @Param("cityLabel") String cityLabel,
            @Param("latitude") double latitude,
            @Param("longitude") double longitude);
}
