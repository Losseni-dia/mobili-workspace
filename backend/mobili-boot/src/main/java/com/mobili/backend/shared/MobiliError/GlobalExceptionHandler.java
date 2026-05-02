package com.mobili.backend.shared.MobiliError;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.shared.MobiliError.exception.ErrorDetails;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private final AnalyticsEventService analyticsEventService;

    public GlobalExceptionHandler(AnalyticsEventService analyticsEventService) {
        this.analyticsEventService = analyticsEventService;
    }

    // 1. GESTION DES ERREURS PERSONNALISÉES
    @ExceptionHandler(MobiliException.class)
    public ResponseEntity<ErrorDetails> handleMobiliException(MobiliException ex, WebRequest request) {
        return buildResponse(ex.getErrorCode(), ex.getMessage(), request);
    }

    // 2. GESTION DES DOUBLONS / CONTRAINTES SQL
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErrorDetails> handleDataIntegrity(DataIntegrityViolationException ex, WebRequest request) {
        String full = ex.getMessage() != null ? ex.getMessage() : "";
        // Chaîne d’exceptions (cause) pour le SQLState PostgreSQL sans dépendre du driver en compile
        String chain = errorChain(ex);
        String message = "Cette ressource existe déjà.";

        // Contrainte CHECK sur vehicle_type (le SQLState 23514 n’est pas toujours dans getMessage()).
        if (full.contains("trips_vehicle_type_check")) {
            message = "Type de véhicule refusé par la base. Redémarrez l’application pour appliquer la mise à jour du schéma (types de véhicule), ou contactez l’administrateur.";
            return buildResponse(MobiliErrorCode.VALIDATION_ERROR, message, request);
        }
        // 23505 = unique_violation (vrai doublon de plaque) — ne pas le confondre avec un 23514 dont
        // le détail d’insert contient aussi « vehicle_plate_number ».
        if (chain.contains("23505")
                && (full.toLowerCase().contains("vehicle_plate") || full.toLowerCase().contains("vehicule_plate"))) {
            message = "Un véhicule avec cette plaque est déjà enregistré.";
            return buildResponse(MobiliErrorCode.DUPLICATE_RESOURCE, message, request);
        }

        return buildResponse(MobiliErrorCode.DUPLICATE_RESOURCE, message, request);
    }

    private static String errorChain(Throwable t) {
        var sb = new StringBuilder(256);
        for (; t != null; t = t.getCause()) {
            sb.append(t.getClass().getName()).append(' ').append(t.getMessage() != null ? t.getMessage() : "").append(' ');
        }
        return sb.toString();
    }

    /**
     * Aucun {@code @RequestMapping} ne correspond (ou ressource statique introuvable en 6.1+).
     * Ne pas confondre avec une vraie erreur serveur : sinon le client reçoit un 500 trompeur.
     */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ErrorDetails> handleNoResource(NoResourceFoundException ex, WebRequest request) {
        String path = ex.getResourcePath() != null ? ex.getResourcePath() : request.getDescription(false);
        return buildResponse(
                MobiliErrorCode.RESOURCE_NOT_FOUND,
                "Aucun endpoint ne correspond : " + path,
                request);
    }

    // 3. GESTION DES ERREURS DE VALIDATION (@Valid)
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Object> handleValidation(MethodArgumentNotValidException ex) {
        Map<String, String> fieldErrors = new HashMap<>();
        ex.getBindingResult().getFieldErrors()
                .forEach(error -> fieldErrors.put(error.getField(), error.getDefaultMessage()));

        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", LocalDateTime.now());
        body.put("status", MobiliErrorCode.VALIDATION_ERROR.getStatus().value());
        body.put("errorCode", MobiliErrorCode.VALIDATION_ERROR.getCode());
        body.put("errors", fieldErrors);

        return new ResponseEntity<>(body, HttpStatus.BAD_REQUEST);
    }

    // 4. FALLBACK (Erreurs imprévues) — n'inclut pas le message (PII / JSON fragile).
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorDetails> handleGlobal(Exception ex, WebRequest request) {
        String safeEx = ex.getClass().getName().replace("\"", "");
        String payload = String.format("{\"exception\":\"%s\"}", safeEx);
        analyticsEventService.record(AnalyticsEventType.SERVER_ERROR, null, payload);
        return buildResponse(MobiliErrorCode.INTERNAL_SERVER_ERROR, ex.getMessage(), request);
    }

    // Méthode utilitaire privée utilisant le Record ErrorDetails
    private ResponseEntity<ErrorDetails> buildResponse(MobiliErrorCode code, String message, WebRequest request) {
        ErrorDetails details = new ErrorDetails(
                LocalDateTime.now(),
                code.getStatus().value(),
                code.getCode(),
                message,
                request.getDescription(false).replace("uri=", ""));
        return new ResponseEntity<>(details, code.getStatus());
    }
}