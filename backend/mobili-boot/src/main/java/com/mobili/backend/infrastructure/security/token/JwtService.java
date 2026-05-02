package com.mobili.backend.infrastructure.security.token;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;
import com.mobili.backend.module.user.entity.User;

import java.security.Key;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class JwtService {

    public static final String CLAIM_TOKEN_TYPE = "typ";
    public static final String TYPE_ACCESS = "access";
    public static final String TYPE_REFRESH = "refresh";

    @Value("${mobili.security.jwt.secret-key}")
    private String secretKey;

    // --- GÉNÉRATION DU TOKEN ---
    public String generateToken(User user) {
        Map<String, Object> claims = new HashMap<>();
        claims.put(CLAIM_TOKEN_TYPE, TYPE_ACCESS);

        // Identité et Rôles
        claims.put("userId", user.getId());
        claims.put("login", user.getLogin());
        claims.put("roles", user.getRoles().stream()
                .map(r -> r.getName().name())
                .collect(Collectors.toList()));

        // Données utilisateur pour le profil
        claims.put("name", user.getFirstname() + " " + user.getLastname());
        claims.put("avatar", user.getAvatarUrl());
        claims.put("email", user.getEmail());

        return Jwts.builder()
                .setClaims(claims)
                .setSubject(user.getLogin())
                .setIssuedAt(new Date(System.currentTimeMillis()))
                // Expiration : 24 heures
                .setExpiration(new Date(System.currentTimeMillis() + 1000 * 60 * 60 * 24))
                .signWith(getSignInKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    /**
     * Jeton de rafraîchissement (même signature que l’accès, claims minimaux) — 7 jours.
     * Ne doit jamais être accepté en {@code Authorization: Bearer} (voir filtre JWT).
     */
    public String generateRefreshToken(User user) {
        Map<String, Object> claims = new HashMap<>();
        claims.put(CLAIM_TOKEN_TYPE, TYPE_REFRESH);
        claims.put("userId", user.getId());
        claims.put("login", user.getLogin());
        return Jwts.builder()
                .setClaims(claims)
                .setSubject(user.getLogin())
                .setIssuedAt(new Date(System.currentTimeMillis()))
                .setExpiration(new Date(System.currentTimeMillis() + 1000L * 60 * 60 * 24 * 7))
                .signWith(getSignInKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    /** Vrai si le JWT (claims) indique le type rafraîchissement. */
    public boolean isRefreshTokenType(String token) {
        if (token == null || token.isBlank()) {
            return false;
        }
        try {
            final Claims c = extractAllClaims(token);
            return TYPE_REFRESH.equals(c.get(CLAIM_TOKEN_TYPE, String.class));
        } catch (Exception e) {
            return false;
        }
    }

    // --- MÉTHODES D'EXTRACTION ---
    public String extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = extractAllClaims(token);
        return claimsResolver.apply(claims);
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(getSignInKey())
                .build()
                .parseClaimsJws(token)
                .getBody();
    }

    // --- VALIDATION ---
    public boolean isTokenValid(String token, UserDetails userDetails) {
        if (isRefreshTokenType(token)) {
            return false;
        }
        final String username = extractUsername(token);
        return (username.equals(userDetails.getUsername()))
                && !isTokenExpired(token)
                && userDetails.isEnabled();
    }

    public boolean isTokenExpired(String token) {
        return extractExpiration(token).before(new Date());
    }

    private Date extractExpiration(String token) {
        return extractClaim(token, Claims::getExpiration);
    }

    // --- RÉCUPÉRATION DE LA CLÉ ---
    private Key getSignInKey() {
        // Décodage de la clé Base64 provenant du .env
        byte[] keyBytes = Decoders.BASE64.decode(secretKey);
        return Keys.hmacShaKeyFor(keyBytes);
    }
}