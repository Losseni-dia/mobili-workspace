package com.mobili.backend.module.partnergarecom.repository;

import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadHidden;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PartnerGareComThreadHiddenRepository
        extends JpaRepository<PartnerGareComThreadHidden, Long> {

    List<PartnerGareComThreadHidden> findByUserId(Long userId);

    List<PartnerGareComThreadHidden> findByStationId(Long stationId);

    boolean existsByThreadIdAndUserId(Long threadId, Long userId);

    boolean existsByThreadIdAndStationId(Long threadId, Long stationId);
}