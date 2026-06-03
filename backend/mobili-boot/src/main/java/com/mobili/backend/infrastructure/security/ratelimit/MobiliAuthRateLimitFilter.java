package com.mobili.backend.infrastructure.security.ratelimit;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import com.mobili.backend.infrastructure.configuration.MobiliRateLimitProperties;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;

/**
 * Limite le débit par IP sur les surfaces anonymes sensibles (auth, inscription gare publique, webhook).
 * Enregistré uniquement comme bean dans {@link com.mobili.backend.infrastructure.security.SecurityConfig}
 * (pas {@code @Component}) pour éviter un double branchement servlet + chaîne Security.
 */
@RequiredArgsConstructor
public class MobiliAuthRateLimitFilter extends OncePerRequestFilter {

    private final MobiliRateLimitProperties props;
    private final MobiliRateLimitStore limitStore;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !props.isEnabled();
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            filterChain.doFilter(request, response);
            return;
        }

        MobiliRateLimitStore.Tier tier = classify(request);
        if (tier == null) {
            filterChain.doFilter(request, response);
            return;
        }

        String ip = resolveClientIp(request);
        if (!limitStore.tryConsume(ip, tier)) {
            response.setStatus(429);
            response.setCharacterEncoding(StandardCharsets.UTF_8.name());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write(
                    "{\"message\":\"Trop de requêtes depuis cette adresse. Réessayez dans une minute.\",\"code\":\"RATE_LIMITED\"}");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private static MobiliRateLimitStore.Tier classify(HttpServletRequest request) {
        String path = normalizePath(request);
        String method = request.getMethod();

        // Après {@code normalizePath} : préfixe context-path (/v1) retiré → /auth/…, /payments/…
        if ("POST".equalsIgnoreCase(method) && path.startsWith("/payments/callback")) {
            return MobiliRateLimitStore.Tier.PAYMENT_WEBHOOK;
        }
        if (!path.startsWith("/auth")) {
            return null;
        }

        if ("GET".equalsIgnoreCase(method) && path.startsWith("/auth/registration/gare/preview")) {
            return MobiliRateLimitStore.Tier.PREVIEW;
        }

        if ("POST".equalsIgnoreCase(method)) {
            if (path.equals("/auth/login")
                    || path.equals("/auth/refresh")
                    || path.equals("/auth/logout")) {
                return MobiliRateLimitStore.Tier.LOGIN_REFRESH;
            }
            if (path.equals("/auth/register")
                    || path.equals("/auth/register-company")
                    || path.equals("/auth/register-carpool-chauffeur")
                    || path.equals("/auth/registration/gare")) {
                return MobiliRateLimitStore.Tier.REGISTER;
            }
        }

        return null;
    }

    private static String normalizePath(HttpServletRequest request) {
        String uri = request.getRequestURI();
        String ctx = request.getContextPath();
        if (ctx != null && !ctx.isEmpty() && uri.startsWith(ctx)) {
            uri = uri.substring(ctx.length());
        }
        if (!uri.startsWith("/")) {
            uri = "/" + uri;
        }
        int q = uri.indexOf('?');
        return q > 0 ? uri.substring(0, q) : uri;
    }

    static String resolveClientIp(HttpServletRequest request) {
        String xf = request.getHeader("X-Forwarded-For");
        if (xf != null && !xf.isBlank()) {
            int comma = xf.indexOf(',');
            String first = comma > 0 ? xf.substring(0, comma).trim() : xf.trim();
            if (!first.isBlank()) {
                return first;
            }
        }
        String addr = request.getRemoteAddr();
        return addr != null ? addr : "unknown";
    }
}
