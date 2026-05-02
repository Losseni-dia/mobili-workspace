package com.mobili.backend.infrastructure.configuration;

import org.springframework.boot.context.properties.ConfigurationProperties;

import lombok.Data;

/** Fenêtres approximées à la minute : limitation IP par type de route publique. */
@Data
@ConfigurationProperties(prefix = "mobili.security.rate-limit")
public class MobiliRateLimitProperties {

    private boolean enabled = true;

    /** POST login, refresh, logout. */
    private int loginRefreshPerMinute = 25;

    /** Inscriptions multiples et inscription gare. */
    private int registerMutationsPerMinute = 10;

    /** GET prévisualisation code gare (évite scan intensif). */
    private int garePreviewPerMinute = 60;

    /** Webhook paiement (secret invalidé → déjà refusé ; limite charge réseau). */
    private int paymentWebhookPerMinute = 120;

    /** Purge des entrées obsolètes (mémoire JVM uniquement). */
    private long purgeDelayMs = 300_000L;

    /** Supprimer les buckets mémoire dont la fenêtre date de plus de N minutes. */
    private int purgeOlderThanMinutes = 12;

    /** Backend Redis optionnel — voir {@code application-redis-rate-limit.yml}. */
    private RedisSettings redis = new RedisSettings();

    @Data
    public static class RedisSettings {

        /**
         * Si {@code true}, utilise Redis pour un débit **global** multi-instance (nécessite
         * {@code spring.data.redis.*} et typiquement le profil {@code redis-rate-limit}).
         */
        private boolean enabled = false;

        /** Préfixe des clés Redis ({@code INCR} par fenêtre minute). */
        private String keyPrefix = "mobili:rl";

        /**
         * Si {@code true} : en cas d’erreur Redis, la requête est **autorisée** (priorité disponibilité).
         * Si {@code false} : retombée sur le compteur **mémoire** JVM (quota dégradé par instance).
         */
        private boolean allowOnRedisFailure = true;
    }
}
