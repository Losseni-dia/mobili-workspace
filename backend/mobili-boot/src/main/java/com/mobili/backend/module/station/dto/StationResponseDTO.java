package com.mobili.backend.module.station.dto;

import java.util.ArrayList;
import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StationResponseDTO {
    private Long id;
    private String name;
    private String city;
    private String code;
    private boolean active;
    private Long partnerId;
    /** PENDING (création) ou APPROVED (exploitation). */
    private String approvalStatus;
    /**
     * Faux à la création ; vrai seulement après validation par le dirigeant.
     * Rétrocompat : si l’API n’a pas de valeur, déduit du statut d’approbation.
     */
    private boolean validated;
    /** Premier responsable gare rattaché (saisi nom / prénom), ou null. */
    private String responsibleName;
    /** Chauffeurs salariés dont l’affectation gare pointe sur cette station. */
    @Builder.Default
    private List<StationChauffeurSummary> assignedChauffeurs = new ArrayList<>();
}
