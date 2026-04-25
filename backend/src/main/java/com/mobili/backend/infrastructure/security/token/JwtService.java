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

    @Value("${mobili.security.jwt.secret-key}")
    private String secretKey;

    // --- GÉNÉRATION DU TOKEN ---
    public String generateToken(User user) {
        Map<String, Object> claims = new HashMap<>();

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
        final String username = extractUsername(token);
        return (username.equals(userDetails.getUsername()))
                && !isTokenExpired(token)
                && userDetails.isEnabled();
    }

    private boolean isTokenExpired(String token) {
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