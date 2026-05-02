package com.mobili.backend.module.partnergarecom.repository;

import java.util.List;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThread;

@Repository
public interface PartnerGareComThreadRepository extends JpaRepository<PartnerGareComThread, Long> {

    boolean existsByPartner_IdAndTitle(Long partnerId, String title);

    @EntityGraph(attributePaths = { "targets", "targets.station" })
    List<PartnerGareComThread> findByPartner_IdOrderByLastActivityAtDesc(Long partnerId);

    @Query("SELECT DISTINCT t FROM PartnerGareComThread t " +
            "LEFT JOIN FETCH t.targets tr " +
            "LEFT JOIN FETCH tr.station " +
            "WHERE t.partner.id = :partnerId AND (" +
            "  t.scope = com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadScope.ALL " +
            "  OR EXISTS (SELECT 1 FROM PartnerGareComThreadTarget x WHERE x.thread = t AND x.station.id = :stationId)" +
            ") ORDER BY t.lastActivityAt DESC")
    List<PartnerGareComThread> findForGareUser(@Param("partnerId") Long partnerId, @Param("stationId") Long stationId);
}
