package com.mobili.backend.infrastructure.security;

import java.util.List;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.multipart.support.StandardServletMultipartResolver;

import com.mobili.backend.infrastructure.configuration.MobiliCorsSettings;
import com.mobili.backend.infrastructure.configuration.MobiliRateLimitProperties;
import com.mobili.backend.infrastructure.security.ratelimit.MobiliAuthRateLimitFilter;
import com.mobili.backend.infrastructure.security.ratelimit.MobiliRateLimitStore;
import com.mobili.backend.infrastructure.security.token.JwtAuthenticationFilter;

/**
 * Filtre JWT + règles par surface API. Les chemins nominaux sont centralisés dans
 * {@link MobiliApiPaths} (phase 2 : modularité du monolithe, un seul JAR).
 * Sans proxy CGLIB (inutile ici) — évite des échecs au démarrage avec DevTools.
 */
@Configuration(proxyBeanMethods = false)
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public MobiliAuthRateLimitFilter mobiliAuthRateLimitFilter(
            MobiliRateLimitProperties props,
            MobiliRateLimitStore store) {
        return new MobiliAuthRateLimitFilter(props, store);
    }

    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            JwtAuthenticationFilter jwtAuthFilter,
            MobiliAuthRateLimitFilter mobiliAuthRateLimitFilter,
            MobiliCorsSettings mobiliCorsSettings)
            throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource(mobiliCorsSettings)))
                .csrf(AbstractHttpConfigurer::disable)
                .headers(headers -> headers
                        .frameOptions(frame -> frame.deny())
                        .contentTypeOptions(Customizer.withDefaults())
                        .referrerPolicy(ref -> ref.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN)))
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // --- Erreur, CORS preflight, fichiers, auth anonyme, catalogue public trajets
                        .requestMatchers("/error", "/error/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/").permitAll()
                        .requestMatchers("/actuator/health", "/actuator/prometheus").permitAll()
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/uploads/users/**", "/uploads/partners/**", "/uploads/vehicles/**")
                        .permitAll()
                        .requestMatchers(HttpMethod.GET, MobiliApiPaths.MEDIA_PRIVATE).authenticated()
                        .requestMatchers(HttpMethod.POST,
                                MobiliApiPaths.AUTH + "/login",
                                MobiliApiPaths.AUTH + "/register",
                                MobiliApiPaths.AUTH + "/register-company",
                                MobiliApiPaths.AUTH + "/register-carpool-chauffeur",
                                MobiliApiPaths.AUTH + "/refresh",
                                MobiliApiPaths.AUTH + "/logout")
                        .permitAll()
                        .requestMatchers(MobiliApiPaths.TRIPS_WILD_DRIVER)
                        .hasAnyAuthority("ROLE_CHAUFFEUR", "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(HttpMethod.GET, MobiliApiPaths.TRIPS_CHAUFFEUR)
                        .hasAnyAuthority("ROLE_CHAUFFEUR", "ROLE_ADMIN")
                        .requestMatchers(HttpMethod.GET, MobiliApiPaths.TRIPS, MobiliApiPaths.TRIPS_GLOB).permitAll()
                        .requestMatchers(MobiliApiPaths.PAYMENTS_CALLBACK).permitAll()
                        .requestMatchers(MobiliApiPaths.AUTH_REGISTRATION).permitAll()
                        // Canal : hors GET public (reste de /trips/** ci-dessus)
                        .requestMatchers(HttpMethod.GET, MobiliApiPaths.TRIPS_WILD_CHANNEL_MESSAGES)
                        .hasAnyAuthority("ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(MobiliApiPaths.INBOX)
                        .hasAnyAuthority("ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_CHAUFFEUR", "ROLE_ADMIN")

                        // Inscription d’une compagnie (utilisateur authentifié, hors admin partners/**)
                        .requestMatchers(HttpMethod.POST, MobiliApiPaths.PARTNERS).authenticated()
                        .requestMatchers(MobiliApiPaths.COVOITURAGE)
                        .hasAnyAuthority("ROLE_CHAUFFEUR", "ROLE_ADMIN")

                        // --- Écriture trajets + espaces pro (compagnie / gare) — {POST,PUT,DELETE} trips
                        .requestMatchers(HttpMethod.POST, MobiliApiPaths.TRIPS, MobiliApiPaths.TRIPS_GLOB)
                        .hasAnyAuthority("ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(HttpMethod.PUT, MobiliApiPaths.TRIPS_GLOB)
                        .hasAnyAuthority("ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(HttpMethod.DELETE, MobiliApiPaths.TRIPS_GLOB)
                        .hasAnyAuthority("ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(
                                MobiliApiPaths.PARTENAIRE_DASHBOARD,
                                MobiliApiPaths.PARTENAIRE_STATIONS,
                                MobiliApiPaths.PARTENAIRE_CHAUFFEURS,
                                MobiliApiPaths.PARTENAIRE_CHAUFFEURS_GLOB)
                        .hasAnyAuthority("ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(MobiliApiPaths.PARTNER_GARE_COM)
                        .hasAnyAuthority("ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(MobiliApiPaths.TRIPS_MY_TRIPS)
                        .hasAnyAuthority("ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")

                        // Profil, réservations, billets (voyageur + pro)
                        .requestMatchers(MobiliApiPaths.AUTH + "/me")
                        .hasAnyAuthority("ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_CHAUFFEUR", "ROLE_ADMIN")
                        .requestMatchers(MobiliApiPaths.BOOKINGS)
                        .hasAnyAuthority("ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(MobiliApiPaths.TICKETS)
                        .hasAnyAuthority("ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_CHAUFFEUR", "ROLE_ADMIN")

                        // Règles /partners : plus spécifiques en premier
                        .requestMatchers(MobiliApiPaths.PARTNERS_MY_COMPANY)
                        .hasAnyAuthority("ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(HttpMethod.PUT, MobiliApiPaths.PARTNERS_GLOB)
                        .hasAnyAuthority("ROLE_PARTNER", "ROLE_ADMIN")
                        .requestMatchers(MobiliApiPaths.PARTNERS_GLOB).hasAnyAuthority("ROLE_ADMIN")
                        .requestMatchers(MobiliApiPaths.ADMIN).hasAnyAuthority("ROLE_ADMIN")

                        .anyRequest().authenticated())
                .addFilterBefore(mobiliAuthRateLimitFilter,
                        org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(jwtAuthFilter,
                        org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public StandardServletMultipartResolver multipartResolver() {
        return new StandardServletMultipartResolver();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource(MobiliCorsSettings mobiliCorsSettings) {
        CorsConfiguration configuration = new CorsConfiguration();
        List<String> origins = mobiliCorsSettings.getAllowedOrigins();
        if (origins == null || origins.isEmpty()) {
            origins = List.of("http://localhost:4200", "http://127.0.0.1:4200");
        }
        configuration.setAllowedOrigins(origins);
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(
                List.of("Authorization", "Content-Type", "Accept", "X-Requested-With", "Last-Event-ID"));
        configuration.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}