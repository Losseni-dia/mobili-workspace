package com.mobili.backend.infrastructure.security;

import java.util.List;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.multipart.support.StandardServletMultipartResolver;

import com.mobili.backend.infrastructure.configuration.MobiliCorsSettings;
import com.mobili.backend.infrastructure.security.token.JwtAuthenticationFilter;

import lombok.RequiredArgsConstructor;

/** Sans proxy CGLIB (inutile ici) — évite des échecs au démarrage avec DevTools. */
@Configuration(proxyBeanMethods = false)
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthFilter;
    private final MobiliCorsSettings mobiliCorsSettings;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // 1. ACCÈS PUBLIC
                        .requestMatchers("/error", "/error/**").permitAll()
                        // Prévol CORS (évite 403 en amont d’authentification)
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/uploads/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/v1/auth/login", "/v1/auth/register", "/v1/auth/register-carpool-chauffeur")
                        .permitAll()
                        .requestMatchers("/v1/trips/*/driver/**")
                        .hasAnyAuthority(new String[] { "ROLE_CHAUFFEUR", "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN" })
                        .requestMatchers(HttpMethod.GET, "/v1/trips/chauffeur/**")
                        .hasAnyAuthority(new String[] { "ROLE_CHAUFFEUR", "ROLE_ADMIN" })
                        .requestMatchers(HttpMethod.GET, "/v1/trips", "/v1/trips/**").permitAll()
                        .requestMatchers("/v1/payments/callback").permitAll()
                        .requestMatchers("/v1/auth/registration/**").permitAll()
                        // Canal voyage : exclu du GET public /v1/trips/** (doit être authentifié)
                        .requestMatchers(HttpMethod.GET, "/v1/trips/*/channel/messages")
                        .hasAnyAuthority(new String[] { "ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN" })
                        .requestMatchers("/v1/inbox/**")
                        .hasAnyAuthority(new String[] { "ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_CHAUFFEUR",
                                "ROLE_ADMIN" })

                        // 2. INSCRIPTION PARTENAIRE (Utilisateur déjà connecté)
                        .requestMatchers(HttpMethod.POST, "/v1/partners").authenticated()

                        // Covoiturage particulier (publication par le conducteur)
                        .requestMatchers("/v1/covoiturage/**")
                        .hasAnyAuthority(new String[] { "ROLE_CHAUFFEUR", "ROLE_ADMIN" })

                        // 3. GESTION DES TRAJETS (POST, PUT, DELETE)
                        // Note : hasAnyAuthority est plus fiable car il matche exactement
                        // "ROLE_PARTNER"
                        .requestMatchers(HttpMethod.POST, "/v1/trips", "/v1/trips/**")
                        .hasAnyAuthority(new String[] { "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN" })
                        .requestMatchers(HttpMethod.PUT, "/v1/trips/**")
                        .hasAnyAuthority(new String[] { "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN" })
                        .requestMatchers(HttpMethod.DELETE, "/v1/trips/**")
                        .hasAnyAuthority(new String[] { "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN" })
                        .requestMatchers(
                                "/v1/partenaire/dashboard/**",
                                "/v1/partenaire/stations/**",
                                "/v1/partenaire/chauffeurs",
                                "/v1/partenaire/chauffeurs/**")
                        .hasAnyAuthority(new String[] { "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN" })
                        .requestMatchers("/v1/partner-gare-com/**")
                        .hasAnyAuthority(new String[] { "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN" })
                        .requestMatchers("/v1/trips/my-trips")
                        .hasAnyAuthority(new String[] { "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN" })

                        // 4. PROFIL ET RÉSERVATIONS
                        .requestMatchers("/v1/auth/me")
                        .hasAnyAuthority(new String[] { "ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_CHAUFFEUR", "ROLE_ADMIN" })
                        .requestMatchers("/v1/bookings/**")
                        .hasAnyAuthority(new String[] { "ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN" })
                        .requestMatchers("/v1/tickets/**")
                        .hasAnyAuthority(new String[] { "ROLE_USER", "ROLE_PARTNER", "ROLE_GARE", "ROLE_CHAUFFEUR", "ROLE_ADMIN" })

                        // 5. ADMINISTRATION DES PARTENAIRES
                        // Plus spécifique en premier (sinon /v1/partners/** n'autorise que l'admin
                        // et my-company / lecteurs partenaire+gare ne matchent jamais)
                        .requestMatchers("/v1/partners/my-company")
                        .hasAnyAuthority("ROLE_PARTNER", "ROLE_GARE", "ROLE_ADMIN")
                        .requestMatchers(HttpMethod.PUT, "/v1/partners/**")
                        .hasAnyAuthority(new String[] { "ROLE_PARTNER", "ROLE_ADMIN" })
                        .requestMatchers("/v1/partners/**").hasAnyAuthority("ROLE_ADMIN")
                        .requestMatchers("/v1/admin/**").hasAnyAuthority("ROLE_ADMIN")

                        .anyRequest().authenticated())
                .addFilterBefore(jwtAuthFilter,
                        org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public StandardServletMultipartResolver multipartResolver() {
        return new StandardServletMultipartResolver();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
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