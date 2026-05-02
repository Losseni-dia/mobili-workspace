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
}