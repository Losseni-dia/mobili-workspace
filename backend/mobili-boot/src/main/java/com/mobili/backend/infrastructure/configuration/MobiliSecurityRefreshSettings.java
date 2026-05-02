package com.mobili.backend.infrastructure.configuration;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Jeton de rafraîchissement (httpOnly) pour le même hôte d’API : partagé par les
 * applications front (ex. 4200 et 4201) sans exposer de secret côté JS.
 */
@ConfigurationProperties(prefix = "mobili.security.refresh")
public class MobiliSecurityRefreshSettings {

    private String cookieName = "MOBILI_REFRESH";
    /** Ex. 604800 = 7 jours */
    private long maxAgeSeconds = 7L * 24 * 60 * 60;
    private String path = "/v1";
    private boolean secure = false;
    private String sameSite = "Lax";

    public String getCookieName() {
        return cookieName;
    }

    public void setCookieName(String cookieName) {
        this.cookieName = cookieName;
    }

    public long getMaxAgeSeconds() {
        return maxAgeSeconds;
    }

    public void setMaxAgeSeconds(long maxAgeSeconds) {
        this.maxAgeSeconds = maxAgeSeconds;
    }

    public String getPath() {
        return path;
    }

    public void setPath(String path) {
        this.path = path;
    }

    public boolean isSecure() {
        return secure;
    }

    public void setSecure(boolean secure) {
        this.secure = secure;
    }

    public String getSameSite() {
        return sameSite;
    }

    public void setSameSite(String sameSite) {
        this.sameSite = sameSite;
    }
}
