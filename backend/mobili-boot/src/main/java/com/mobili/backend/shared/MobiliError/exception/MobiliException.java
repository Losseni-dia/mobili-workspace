package com.mobili.backend.shared.mobiliError.exception;

import lombok.Getter;

import java.util.Map;

@Getter
public class MobiliException extends RuntimeException {
    private final MobiliErrorCode errorCode;
    private final Map<String, String> fieldErrors;

    public MobiliException(MobiliErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
        this.fieldErrors = null;
    }

    // Permet de surcharger le message par défaut si besoin
    public MobiliException(MobiliErrorCode errorCode, String customMessage) {
        super(customMessage);
        this.errorCode = errorCode;
        this.fieldErrors = null;
    }

    // Permet d'attacher des erreurs par champ (ex: email/login déjà utilisé)
    public MobiliException(MobiliErrorCode errorCode, String customMessage, Map<String, String> fieldErrors) {
        super(customMessage);
        this.errorCode = errorCode;
        this.fieldErrors = fieldErrors;
    }
}