package com.mobili.backend.shared.MobiliError.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public enum MobiliErrorCode {
    // Erreurs Communes
    INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "MOB-001", "Une erreur interne est survenue."),
    RESOURCE_NOT_FOUND(HttpStatus.NOT_FOUND, "MOB-002", "La ressource demandée n'existe pas."),
    VALIDATION_ERROR(HttpStatus.BAD_REQUEST, "MOB-003", "Données invalides."),

    
    NO_SEATS_AVAILABLE(HttpStatus.CONFLICT, "TRP-001", "Plus de places disponibles pour ce trajet."),
    VEHICLE_ALREADY_ASSIGNED(HttpStatus.CONFLICT, "VHC-001",
            "Ce véhicule est déjà assigné à un autre trajet sur cette période."),
                    
    TICKET_ALREADY_USED(HttpStatus.CONFLICT, "BKG-002", "Ce ticket a déjà été utilisé."),
    TICKET_CANCELLED(HttpStatus.CONFLICT, "BKG-003", "Ce ticket a été annulé et ne peut plus être utilisé."),
    TICKET_EXPIRED(HttpStatus.CONFLICT, "BKG-004", "Désolé, ce ticket a expiré"),
                            
    DUPLICATE_RESOURCE(HttpStatus.CONFLICT, "MOB-004", "Cette ressource existe déjà."),

    
    BOOKING_ALREADY_CANCELLED(HttpStatus.BAD_REQUEST, "BKG-001", "Cette réservation est déjà annulée."),
            INSUFFICIENT_BALANCE(HttpStatus.CONFLICT, "PAY-001", "Solde insuffisant !"),
        
    INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "AUTH-001", "Identifiants incorrects."),
    ACCESS_DENIED(HttpStatus.FORBIDDEN, "AUTH-002", "Vous n'avez pas les droits nécessaires."),

    BOARDING_CLOSED(HttpStatus.CONFLICT, "TRP-002",
            "Plus de réservation avec embarquement à cet arrêt (départ enregistré ou heure planifiée dépassée).");

    private final HttpStatus status;
    private final String code;
    private final String message;

    MobiliErrorCode(HttpStatus status, String code, String message) {
        this.status = status;
        this.code = code;
        this.message = message;
    }
}