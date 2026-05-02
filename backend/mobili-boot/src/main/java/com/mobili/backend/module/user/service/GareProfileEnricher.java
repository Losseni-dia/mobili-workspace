package com.mobili.backend.module.user.service;

import org.springframework.stereotype.Component;

import com.mobili.backend.module.station.service.StationService;
import com.mobili.backend.module.user.dto.ProfileDTO;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.role.UserRole;

import lombok.RequiredArgsConstructor;

/**
 * Ajoute au profil la possibilité d’agir en gare (trajets, scanner, etc.) selon
 * {@link com.mobili.backend.module.station.entity.Station#getValidated()}.
 */
@Component
@RequiredArgsConstructor
public class GareProfileEnricher {

    private final StationService stationService;

    public void enrich(ProfileDTO dto, User user) {
        if (dto == null || user == null || user.getStation() == null) {
            return;
        }
        if (user.getRoles() == null) {
            return;
        }
        boolean gare = user.getRoles().stream().anyMatch(r -> r.getName() == UserRole.GARE);
        if (!gare) {
            return;
        }
        dto.setGareOperationsEnabled(stationService.isStationOperational(user.getStation()));
    }
}
