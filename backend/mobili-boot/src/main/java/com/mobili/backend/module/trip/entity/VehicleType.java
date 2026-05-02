package com.mobili.backend.module.trip.entity;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;
import java.util.Arrays;

public enum VehicleType {
    BUS_CLIMATISE("Bus Climatisé"),
    BUS_CLASSIQUE("Bus Classique"),
    CAR_70_PLACES("Car 70 places"),
    MINIBUS("Minibus"),
    MASSA_NORMAL("Massa normal"),
    MASSA_6_ROUES("Massa 6 roues"),
    VAN("Van"),
    /** Voitures particulières (covoiturage, offres légères) */
    SUV("SUV"),
    BERLINE("Berline"),
    CITADINE("Citadine"),
    MONOSPACE("Monospace"),
    PICKUP("Pick-up");

    private final String label;

    VehicleType(String label) {
        this.label = label;
    }

    @JsonValue
    public String getLabel() {
        return label;
    }

    // 💡 Ce décodeur permet de lire "MINIBUS" ou "Minibus" sans erreur 500
    @JsonCreator
    public static VehicleType fromString(String value) {
        return Arrays.stream(VehicleType.values())
                .filter(type -> type.name().equalsIgnoreCase(value) ||
                        type.label.equalsIgnoreCase(value))
                .findFirst()
                .orElse(null);
    }
}