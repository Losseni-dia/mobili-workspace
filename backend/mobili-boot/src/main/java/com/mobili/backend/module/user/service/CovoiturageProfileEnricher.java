package com.mobili.backend.module.user.service;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

import org.springframework.stereotype.Component;

import com.mobili.backend.module.user.dto.ProfileDTO;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.role.CovoiturageKycStatus;
import com.mobili.backend.module.user.role.UserRole;

@Component
public class CovoiturageProfileEnricher {

    public void enrich(ProfileDTO dto, User user) {
        if (dto == null || user == null) {
            return;
        }
        if (user.getRoles() == null
                || user.getRoles().stream().noneMatch(r -> r.getName() == UserRole.CHAUFFEUR)) {
            return;
        }
        if (user.getCovoiturageKycStatus() == null
                || user.getCovoiturageKycStatus() == CovoiturageKycStatus.NONE) {
            return;
        }
        LocalDate end = user.getCovoiturageIdValidUntil();
        if (end == null) {
            return;
        }
        LocalDate today = LocalDate.now();
        long days = ChronoUnit.DAYS.between(today, end);
        dto.setCovoiturageKycDaysUntilExpiry(days);
        dto.setCovoiturageKycIsDocumentExpired(days < 0);
        dto.setCovoiturageKycExpiringWithin30Days(days >= 0 && days <= 30);
    }
}
