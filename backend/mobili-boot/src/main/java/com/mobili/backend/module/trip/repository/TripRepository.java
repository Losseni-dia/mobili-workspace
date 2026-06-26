package com.mobili.backend.module.trip.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.mobili.backend.module.trip.entity.Trip;

@Repository
public interface TripRepository extends JpaRepository<Trip, Long> {

    /**
     * Catalogue voyageur : un trajet disparaît une fois son heure passée OU une
     * fois {@code TERMINÉ} / {@code ANNULÉ} ; un trajet {@code EN_COURS} reste
     * visible quelle que soit son heure de départ (le car a déjà décollé).
     */
    @Query("SELECT DISTINCT t FROM Trip t JOIN FETCH t.partner LEFT JOIN FETCH t.station "
            + "LEFT JOIN FETCH t.assignedChauffeur LEFT JOIN FETCH t.stops "
            + "WHERE t.status <> com.mobili.backend.module.trip.entity.TripStatus.ANNULÉ "
            + "AND t.status <> com.mobili.backend.module.trip.entity.TripStatus.TERMINÉ "
            + "AND (t.status = com.mobili.backend.module.trip.entity.TripStatus.EN_COURS "
            + "     OR t.departureDateTime >= ?1) "
            + "ORDER BY t.departureDateTime ASC")
    List<Trip> findAllUpcomingTrips(LocalDateTime startDateTime);

    @Query("SELECT t FROM Trip t LEFT JOIN FETCH t.partner WHERE t.id = ?1")
    Optional<Trip> findByIdWithPartner(Long id);

    @Query("SELECT DISTINCT t FROM Trip t LEFT JOIN FETCH t.partner LEFT JOIN FETCH t.station "
            + "LEFT JOIN FETCH t.assignedChauffeur "
            + "LEFT JOIN FETCH t.covoiturageOrganizer LEFT JOIN FETCH t.stops WHERE t.id = :id")
    Optional<Trip> findByIdWithPartnerAndStops(@Param("id") Long id);

    @Query("SELECT t FROM Trip t LEFT JOIN FETCH t.partner")
    List<Trip> findAllWithPartner();

    @Query("SELECT COUNT(t) FROM Trip t WHERE t.partner.id = ?1")
    long countTripsByPartner(Long partnerId);

    @Query("SELECT COUNT(t) FROM Trip t WHERE t.partner.id = :partnerId AND t.station.id = :stationId")
    long countTripsByPartnerAndStation(@Param("partnerId") Long partnerId, @Param("stationId") Long stationId);

    /** Dashboard conducteur covoiturage : trajets de l'organisateur, jamais ceux du pool entier. */
    @Query("SELECT COUNT(t) FROM Trip t WHERE t.covoiturageOrganizer.id = :organizerId")
    long countTripsByCovoiturageOrganizer(@Param("organizerId") Long organizerId);

    @Query("SELECT DISTINCT t FROM Trip t LEFT JOIN FETCH t.partner LEFT JOIN FETCH t.station "
            + "LEFT JOIN FETCH t.assignedChauffeur "
            + "WHERE t.partner.id = ?1 ORDER BY t.departureDateTime DESC")
    List<Trip> findAllByPartnerId(Long partnerId);

    @Query("SELECT DISTINCT t FROM Trip t LEFT JOIN FETCH t.partner LEFT JOIN FETCH t.station "
            + "LEFT JOIN FETCH t.assignedChauffeur "
            + "WHERE t.partner.id = :partnerId AND t.station.id = :stationId ORDER BY t.departureDateTime DESC")
    List<Trip> findAllByPartnerIdAndStationId(@Param("partnerId") Long partnerId, @Param("stationId") Long stationId);

    @Query("SELECT DISTINCT t FROM Trip t LEFT JOIN FETCH t.partner LEFT JOIN FETCH t.station "
            + "WHERE t.covoiturageOrganizer.id = :userId ORDER BY t.departureDateTime DESC")
    List<Trip> findAllByCovoiturageOrganizerId(@Param("userId") Long userId);

    /**
     * Ligne compagnie : services assignés, non terminés, récents ou en cours d’exécution.
     */
    @Query("SELECT DISTINCT t FROM Trip t JOIN FETCH t.partner p LEFT JOIN FETCH t.station s "
            + "WHERE t.assignedChauffeur.id = :uid AND t.covoiturageOrganizer IS NULL "
            + "AND t.status <> com.mobili.backend.module.trip.entity.TripStatus.ANNULÉ "
            + "AND t.status <> com.mobili.backend.module.trip.entity.TripStatus.TERMINÉ "
            + "AND (t.status = com.mobili.backend.module.trip.entity.TripStatus.EN_COURS "
            + "     OR t.departureDateTime >= :from) "
            + "ORDER BY t.departureDateTime ASC")
    List<Trip> findAssignedChauffeurUpcoming(
            @Param("uid") Long uid, @Param("from") LocalDateTime from);

    @Query("SELECT DISTINCT t FROM Trip t JOIN FETCH t.partner p LEFT JOIN FETCH t.station s "
            + "WHERE t.assignedChauffeur.id = :uid AND t.covoiturageOrganizer IS NULL "
            + "AND (t.status = com.mobili.backend.module.trip.entity.TripStatus.TERMINÉ "
            + "     OR t.status = com.mobili.backend.module.trip.entity.TripStatus.ANNULÉ "
            + "     OR (t.status = com.mobili.backend.module.trip.entity.TripStatus.PROGRAMMÉ "
            + "         AND t.departureDateTime < :now)) "
            + "ORDER BY t.departureDateTime DESC")
    List<Trip> findAssignedChauffeurHistory(@Param("uid") Long uid, @Param("now") LocalDateTime now, Pageable page);
}
