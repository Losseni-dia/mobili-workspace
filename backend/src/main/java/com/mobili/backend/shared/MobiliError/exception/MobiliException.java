package com.mobili.backend.shared.MobiliError.exception;


import lombok.Getter;

@Getter
public class MobiliException extends RuntimeException {
    private final MobiliErrorCode errorCode;

    public MobiliException(MobiliErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    // Permet de surcharger le message par défaut si besoin
    public MobiliException(MobiliErrorCode errorCode, String customMessage) {
        super(customMessage);
        this.errorCode = errorCode;
    }
}