package com.mobili.backend.infrastructure.security.auth;

import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Component;

import com.mobili.backend.infrastructure.configuration.MobiliSecurityRefreshSettings;
import com.mobili.backend.infrastructure.security.token.JwtService;
import com.mobili.backend.module.user.entity.User;

import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class RefreshTokenCookieWriter {

    private final JwtService jwtService;
    private final MobiliSecurityRefreshSettings refreshSettings;

    public void write(HttpServletResponse response, User user) {
        String refresh = jwtService.generateRefreshToken(user);
        response.addHeader(HttpHeaders.SET_COOKIE, buildCookie(refresh, refreshSettings.getMaxAgeSeconds()).toString());
    }

    /** Efface le cookie côté navigateur (logout). */
    public void clear(HttpServletResponse response) {
        response.addHeader(HttpHeaders.SET_COOKIE,
                buildCookie("", 0).toString());
    }

    private ResponseCookie buildCookie(String value, long maxAgeSeconds) {
        return ResponseCookie.from(refreshSettings.getCookieName(), value)
                .httpOnly(true)
                .path(refreshSettings.getPath())
                .maxAge(maxAgeSeconds)
                .sameSite(refreshSettings.getSameSite())
                .secure(refreshSettings.isSecure())
                .build();
    }
}
