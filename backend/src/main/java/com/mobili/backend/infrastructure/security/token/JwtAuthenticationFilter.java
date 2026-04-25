package com.mobili.backend.infrastructure.security.token;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.mobili.backend.infrastructure.security.authentication.UserDetailsServiceImpl;

import io.jsonwebtoken.JwtException;
import java.io.IOException;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService; // Ton service de gestion des tokens
    private final UserDetailsServiceImpl userDetailsService;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        final String authHeader = request.getHeader("Authorization");
        final String jwt;
        final String userLogin;
        
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        try {
            // 2. Extraire le token (on enlève "Bearer ")
            jwt = authHeader.substring(7);
            userLogin = jwtService.extractUsername(jwt);
        } catch (JwtException | IllegalArgumentException e) {
            // Ne pas couper la requête : les routes publiques (ex. GET /v1/trips) doivent
            // rester accessibles ; un JWT expiré mal stocké côté client ne bloque plus le catalogue.
            SecurityContextHolder.clearContext();
            filterChain.doFilter(request, response);
            return;
        }

        // 3. Si on a un login et que l'utilisateur n'est pas encore authentifié dans le
        // contexte
        if (userLogin != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            UserDetails userDetails = this.userDetailsService.loadUserByUsername(userLogin);

            // 4. Si le token est valide, on crée l'objet d'authentification pour Spring
            // Security
            if (jwtService.isTokenValid(jwt, userDetails)) {
                UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(
                        userDetails,
                        null,
                        userDetails.getAuthorities());
                authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

                // On informe Spring Security que l'utilisateur est officiellement connecté
                SecurityContextHolder.getContext().setAuthentication(authToken);
            }
        }
        filterChain.doFilter(request, response);
    }
}