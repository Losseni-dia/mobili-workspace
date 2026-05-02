package com.mobili.backend.module.partnergarecom.repository;

import java.util.List;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.mobili.backend.module.partnergarecom.entity.PartnerGareComMessage;

@Repository
public interface PartnerGareComMessageRepository extends JpaRepository<PartnerGareComMessage, Long> {

    @EntityGraph(attributePaths = { "author" })
    List<PartnerGareComMessage> findByThread_IdOrderByCreatedAtAsc(Long threadId);
}
