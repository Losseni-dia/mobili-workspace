package com.mobili.backend.module.claim.repository;

import com.mobili.backend.module.claim.entity.Claim;
import com.mobili.backend.module.claim.enums.ClaimStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ClaimRepository extends JpaRepository<Claim, Long> {

    @Query("SELECT c FROM Claim c WHERE c.user.id = :userId ORDER BY c.createdAt DESC")
    List<Claim> findByUserIdOrderByCreatedAtDesc(@Param("userId") Long userId);

    List<Claim> findByStatusOrderByCreatedAtDesc(ClaimStatus status);

    List<Claim> findAllByOrderByCreatedAtDesc();

    /** Contrôle d'accès pièce jointe — voir PrivateMediaService.mayAccess. */
    boolean existsByAttachmentPathAndUser_Id(String attachmentPath, Long userId);
}
