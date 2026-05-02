package com.mobili.backend.module.trip.dto.driver;

import lombok.Data;

@Data
public class DriverAlightedRequest {

    /** Si absent, l’arrêt prévu sur le billet est utilisé. */
    private Integer stopIndex;
}
