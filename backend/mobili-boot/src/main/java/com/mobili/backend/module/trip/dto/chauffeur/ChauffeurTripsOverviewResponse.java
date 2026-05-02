package com.mobili.backend.module.trip.dto.chauffeur;

import java.util.List;

import lombok.Data;

@Data
public class ChauffeurTripsOverviewResponse {
    /** Services à venir ou en cours. */
    private List<ChauffeurTripListItem> upcoming;
    /** Derniers trajets effectués. */
    private List<ChauffeurTripListItem> history;
}
