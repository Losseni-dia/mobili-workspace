package com.mobili.backend.infrastructure.configuration;

import java.util.ArrayList;
import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Origines CORS autorisées (liste) — surchargées par profil (dev / acc / prod) ou variables d’environnement.
 */
@ConfigurationProperties(prefix = "mobili.cors")
public class MobiliCorsSettings {

    private List<String> allowedOrigins = new ArrayList<>(
            List.of("http://localhost:4200", "http://127.0.0.1:4200"));

    public List<String> getAllowedOrigins() {
        return allowedOrigins;
    }

    public void setAllowedOrigins(List<String> allowedOrigins) {
        this.allowedOrigins = allowedOrigins != null ? allowedOrigins : new ArrayList<>();
    }
}
