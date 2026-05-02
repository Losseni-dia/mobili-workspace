package com.mobili.backend.module.user.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.mobili.backend.module.user.entity.User;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    // 1. Pour getMyProfile (Recherche par Login avec Fetch)
    @Query("SELECT u FROM User u " +
            "LEFT JOIN FETCH u.roles " +
            "LEFT JOIN FETCH u.partner " +
            "LEFT JOIN FETCH u.employerPartner " +
            "LEFT JOIN FETCH u.station s " +
            "LEFT JOIN FETCH s.partner " +
            "LEFT JOIN FETCH u.chauffeurAffiliationStation " +
            "WHERE u.login = :login")
    Optional<User> findByLogin(@Param("login") String login);

    // 2. Pour findById (Recherche par ID avec Fetch)
    @Query("SELECT u FROM User u " +
            "LEFT JOIN FETCH u.roles " +
            "LEFT JOIN FETCH u.partner " +
            "LEFT JOIN FETCH u.employerPartner " +
            "LEFT JOIN FETCH u.station s " +
            "LEFT JOIN FETCH s.partner " +
            "LEFT JOIN FETCH u.chauffeurAffiliationStation " +
            "WHERE u.id = :id")
    Optional<User> findByIdWithEverything(@Param("id") Long id);

    /** Liste admin (profil) : évite LazyInitialization sur station / partner. */
    @Query("SELECT DISTINCT u FROM User u " +
            "LEFT JOIN FETCH u.roles " +
            "LEFT JOIN FETCH u.partner " +
            "LEFT JOIN FETCH u.employerPartner " +
            "LEFT JOIN FETCH u.station s " +
            "LEFT JOIN FETCH s.partner " +
            "LEFT JOIN FETCH u.chauffeurAffiliationStation")
    List<User> findAllForProfileDto();

    // 3. Utilitaires pour l'inscription et les doublons
    Optional<User> findByEmail(String email);

    boolean existsByLogin(String login);

    boolean existsByEmail(String email);

    @Query("SELECT u.id FROM User u JOIN u.roles r WHERE r.name = com.mobili.backend.module.user.role.UserRole.GARE "
            + "AND u.station IS NOT NULL AND u.station.id = :stationId")
    List<Long> findGareUserIdsByStationId(@Param("stationId") Long stationId);

    @Query("SELECT u FROM User u JOIN u.roles r WHERE r.name = com.mobili.backend.module.user.role.UserRole.GARE "
            + "AND u.station IS NOT NULL AND u.station.id = :stationId ORDER BY u.id ASC")
    List<User> findGareUsersByStationIdOrderByIdAsc(@Param("stationId") Long stationId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE User u SET u.enabled = true WHERE u.station.id = :stationId")
    int enableUsersForStation(@Param("stationId") Long stationId);

    @Query("SELECT DISTINCT u.id FROM User u JOIN u.roles r JOIN u.station s "
            + "WHERE r.name = com.mobili.backend.module.user.role.UserRole.GARE "
            + "AND s.partner.id = :partnerId")
    List<Long> findGareUserIdsByPartnerId(@Param("partnerId") Long partnerId);

    @Query("SELECT DISTINCT u FROM User u JOIN FETCH u.roles r JOIN u.station s "
            + "WHERE r.name = com.mobili.backend.module.user.role.UserRole.GARE "
            + "AND s.partner.id = :partnerId")
    List<User> findGareUsersByPartnerId(@Param("partnerId") Long partnerId);

    @Query("SELECT DISTINCT u FROM User u JOIN u.roles r WHERE r.name = com.mobili.backend.module.user.role.UserRole.CHAUFFEUR")
    List<User> findUsersWithChauffeurRole();

    @Query("SELECT DISTINCT u FROM User u JOIN u.roles r WHERE r.name = com.mobili.backend.module.user.role.UserRole.ADMIN")
    List<User> findUsersWithAdminRole();

    /**
     * Chauffeurs covoiturage (rôle {@code CHAUFFEUR}) dont le KYC covoiturage est approuvé — statut
     * « partenaire covoiturage » côté produit une fois la demande validée.
     */
    @Query("SELECT u.id FROM User u JOIN u.roles r WHERE r.name = com.mobili.backend.module.user.role.UserRole.CHAUFFEUR "
            + "AND u.covoiturageKycStatus = com.mobili.backend.module.user.role.CovoiturageKycStatus.APPROVED "
            + "AND u.enabled = true")
    List<Long> findEnabledCovoiturageChauffeurKycApprovedUserIds();

    @Query("SELECT u.id FROM User u JOIN u.roles r WHERE r.name = com.mobili.backend.module.user.role.UserRole.CHAUFFEUR "
            + "AND u.covoiturageKycStatus = com.mobili.backend.module.user.role.CovoiturageKycStatus.APPROVED")
    List<Long> findAllCovoiturageChauffeurKycApprovedUserIds();

    /**
     * Inscriptions « chauffeur covoiturage particulier » (flag profil) — page admin partenaires / pool.
     */
    @Query("SELECT u FROM User u WHERE u.covoiturageSoloProfile = true ORDER BY LOWER(u.lastname), LOWER(u.firstname), u.id")
    List<User> findCovoiturageSoloProfileUsersOrderByName();

    /**
     * Chauffeurs société : rôle CHAUFFEUR et rattachement employeur vers le partenaire donné.
     */
    /**
     * Tri affichage : {@link com.mobili.backend.module.partner.service.PartnerChauffeurService}
     * (ordre insensible à la casse) — pas de LOWER/ORDER BY en JPQL pour éviter DISTINCT + ORDER BY
     * incompatibles avec PostgreSQL.
     */
    @Query("SELECT u FROM User u "
            + "LEFT JOIN FETCH u.chauffeurAffiliationStation "
            + "JOIN u.roles r "
            + "WHERE r.name = com.mobili.backend.module.user.role.UserRole.CHAUFFEUR "
            + "AND u.employerPartner IS NOT NULL AND u.employerPartner.id = :partnerId")
    List<User> findChauffeursByEmployerPartnerId(@Param("partnerId") Long partnerId);

    @Query("SELECT u FROM User u JOIN u.roles r "
            + "WHERE r.name = com.mobili.backend.module.user.role.UserRole.CHAUFFEUR "
            + "AND u.chauffeurAffiliationStation IS NOT NULL "
            + "AND u.chauffeurAffiliationStation.id IN :stationIds")
    List<User> findChauffeursByAffiliationStationIds(@Param("stationIds") List<Long> stationIds);
}