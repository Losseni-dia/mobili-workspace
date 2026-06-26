package com.mobili.backend.module.admincom.repository;

import com.mobili.backend.module.admincom.entity.AdminComMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface AdminComMessageRepository extends JpaRepository<AdminComMessage, Long> {
    List<AdminComMessage> findByThread_IdOrderByCreatedAtAsc(Long threadId);
}