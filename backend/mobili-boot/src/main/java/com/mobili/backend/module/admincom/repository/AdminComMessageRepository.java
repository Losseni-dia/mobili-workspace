package com.mobili.backend.module.admincom.repository;

import com.mobili.backend.module.admincom.entity.AdminComMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface AdminComMessageRepository extends JpaRepository<AdminComMessage, Long> {
    List<AdminComMessage> findByThread_IdOrderByCreatedAtAsc(Long threadId);

    /** Contrôle d'accès pièce jointe — voir PrivateMediaService.mayAccess : accessible aux deux participants du fil. */
    @Query("SELECT COUNT(m) > 0 FROM AdminComMessage m WHERE m.attachmentPath = :path "
            + "AND (m.thread.adminUser.id = :userId OR m.thread.partnerUser.id = :userId)")
    boolean existsAccessibleAttachment(@Param("path") String path, @Param("userId") Long userId);
}