package com.mobili.backend.infrastructure.security.ratelimit;

import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.mobili.backend.infrastructure.configuration.MobiliRateLimitProperties;

import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class MobiliRateLimitStore {

    private static final Logger log = LoggerFactory.getLogger(MobiliRateLimitStore.class);

    /** TTL des clés Redis après la première écriture (secondes). */
    private static final long REDIS_KEY_TTL_SECONDS = 120L;

    public enum Tier {
        LOGIN_REFRESH,
        REGISTER,
        PREVIEW,
        PAYMENT_WEBHOOK,
    }

    private static final class Bucket {
        volatile long minute;
        final AtomicInteger count = new AtomicInteger(0);
    }

    private final MobiliRateLimitProperties props;

    /** Présent dès que Redis est configuré (auto-config Spring). Absent si pas de connexion Redis. */
    @Autowired(required = false)
    private StringRedisTemplate stringRedisTemplate;

    private final ConcurrentHashMap<String, Bucket> buckets = new ConcurrentHashMap<>();

    /** @return {@code true} si la requête est autorisée */
    public boolean tryConsume(String clientIp, Tier tier) {
        if (!props.isEnabled()) {
            return true;
        }
        int limit = limitFor(tier);
        if (limit <= 0) {
            return true;
        }

        if (props.getRedis().isEnabled() && stringRedisTemplate != null) {
            try {
                return tryConsumeRedis(clientIp, tier, limit);
            } catch (Exception e) {
                log.warn("Rate limit Redis indisponible (tier={}) : {}", tier, e.toString());
                if (props.getRedis().isAllowOnRedisFailure()) {
                    return true;
                }
                return tryConsumeMemory(clientIp, tier, limit);
            }
        }

        if (props.getRedis().isEnabled() && stringRedisTemplate == null) {
            log.warn(
                    "mobili.security.rate-limit.redis.enabled=true mais aucun StringRedisTemplate — "
                            + "vérifiez spring.data.redis.* et le profil redis-rate-limit.");
        }

        return tryConsumeMemory(clientIp, tier, limit);
    }

    private boolean tryConsumeRedis(String clientIp, Tier tier, int limit) {
        long minute = System.currentTimeMillis() / 60_000L;
        String prefix = props.getRedis().getKeyPrefix().trim();
        if (prefix.isEmpty()) {
            prefix = "mobili:rl";
        }
        String key = prefix + ":" + tier.name() + ":" + redisSafeSegment(clientIp) + ":" + minute;
        Long count = stringRedisTemplate.opsForValue().increment(key);
        if (count != null && count == 1L) {
            Boolean expireOk = stringRedisTemplate.expire(key, Duration.ofSeconds(REDIS_KEY_TTL_SECONDS));
            if (Boolean.FALSE.equals(expireOk)) {
                log.debug("Expire Redis rate-limit key ignored ou déjà absente : {}", key);
            }
        }
        return count != null && count <= limit;
    }

    private boolean tryConsumeMemory(String clientIp, Tier tier, int limit) {
        long minute = System.currentTimeMillis() / 60_000L;
        String key = tier.name() + ":" + clientIp;
        Bucket b = buckets.computeIfAbsent(key, k -> new Bucket());
        synchronized (b) {
            if (b.minute != minute) {
                b.minute = minute;
                b.count.set(0);
            }
            int next = b.count.incrementAndGet();
            return next <= limit;
        }
    }

    private static String redisSafeSegment(String ip) {
        if (ip == null || ip.isBlank()) {
            return "unknown";
        }
        return ip.trim().replace(':', '_').replace('\r', '_').replace('\n', '_');
    }

    private int limitFor(Tier tier) {
        return switch (tier) {
            case LOGIN_REFRESH -> props.getLoginRefreshPerMinute();
            case REGISTER -> props.getRegisterMutationsPerMinute();
            case PREVIEW -> props.getGarePreviewPerMinute();
            case PAYMENT_WEBHOOK -> props.getPaymentWebhookPerMinute();
        };
    }

    @Scheduled(fixedDelayString = "${mobili.security.rate-limit.purge-delay-ms:300000}")
    void purgeStaleBuckets() {
        long cut = System.currentTimeMillis() / 60_000L - props.getPurgeOlderThanMinutes();
        buckets.entrySet().removeIf(e -> {
            Bucket b = e.getValue();
            synchronized (b) {
                return b.minute < cut;
            }
        });
    }
}
