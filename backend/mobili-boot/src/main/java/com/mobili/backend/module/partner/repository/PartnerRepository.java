package com.mobili.backend.module.partner.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.mobili.backend.module.partner.entity.Partner;

import java.util.Optional;

@Repository
public interface PartnerRepository extends JpaRepository<Partner, Long> {

    // Pour vérifier si une société existe déjà avec cet email
    Optional<Partner> findByEmail(String email);

    // Pour l'Admin : lister uniquement les sociétés actives
    Iterable<Partner> findAllByEnabledTrue();

   @Query("SELECT p FROM Partner p WHERE p.owner.id = :userId")
    Optional<Partner> findByOwnerId(@Param("userId") Long userId);

    Optional<Partner> findByRegistrationCodeIgnoreCase(String registrationCode);

    boolean existsByBusinessNumberIgnoreCase(String businessNumber);

    boolean existsByEmailIgnoreCase(String email);

    boolean existsByPhone(String phone);

    @Query("SELECT COUNT(p) FROM Partner p WHERE CAST(p.createdAt AS date) = :date")
    long countByCreatedAtDate(@Param("date") java.time.LocalDate date);

    @Query(value = "SELECT DATE(created_at) as day, COUNT(*) as cnt FROM partners " +
            "WHERE created_at >= :from AND created_at <= :to GROUP BY DATE(created_at) ORDER BY DATE(created_at) ASC", nativeQuery = true)
    java.util.List<Object[]> dailyPartnersRegisteredBetween(@Param("from") java.time.LocalDateTime from,
            @Param("to") java.time.LocalDateTime to);

    /** Contrôle d'accès pièce jointe — voir PrivateMediaService.mayAccess. */
    @Query("SELECT p FROM Partner p WHERE p.transportCardFrontUrl = :path OR p.transportCardBackUrl = :path")
    Optional<Partner> findByTransportCardPath(@Param("path") String path);
}