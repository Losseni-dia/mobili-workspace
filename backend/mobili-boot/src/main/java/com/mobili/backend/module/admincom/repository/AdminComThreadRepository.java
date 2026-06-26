package com.mobili.backend.module.admincom.repository;

import com.mobili.backend.module.admincom.entity.AdminComThread;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface AdminComThreadRepository extends JpaRepository<AdminComThread, Long> {
    List<AdminComThread> findByAdminUser_IdOrPartnerUser_IdOrderByLastActivityAtDesc(Long adminId, Long partnerId);

    @Query("SELECT t FROM AdminComThread t WHERE t.adminUser.id = :userId OR t.partnerUser.id = :userId ORDER BY t.lastActivityAt DESC")
    List<AdminComThread> findAllForUser(@Param("userId") Long userId);
}