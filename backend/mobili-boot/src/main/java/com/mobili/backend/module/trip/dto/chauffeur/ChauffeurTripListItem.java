package com.mobili.backend.module.trip.dto.chauffeur;

import java.time.LocalDateTime;

import lombok.Data;

@Data
public class ChauffeurTripListItem {
    private Long id;
    /** "ASSIGNED" = ligne compagnie (vous y êtes affecté) ; "COVOITURAGE" = offre covoiturage (vous l’organisez). */
    private String source;
    private String departureCity;
    private String arrivalCity;
    private String boardingPoint;
    private LocalDateTime departureDateTime;
    private String status;
    private String partnerName;
    private String stationName;
    private String vehiculePlateNumber;
    private String vehicleType;
}
