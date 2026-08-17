package com.mobili.backend.api.passenger.auth;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.configuration.MobiliSecurityRefreshSettings;
import com.mobili.backend.infrastructure.security.auth.RefreshTokenCookieWriter;
import com.mobili.backend.infrastructure.security.token.JwtService;
import com.mobili.backend.module.admin.entity.LoginEvent;
import com.mobili.backend.module.admin.repository.LoginEventRepository;
import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.user.dto.ProfileDTO;
import com.mobili.backend.module.user.dto.RegisterCompanyPublicDTO;
import com.mobili.backend.module.user.dto.RegisterCarpoolChauffeurDTO;
import com.mobili.backend.module.user.dto.RegisterDTO;
import com.mobili.backend.module.user.dto.login.AuthResponse;
import com.mobili.backend.module.user.dto.login.LoginRequest;
import com.mobili.backend.module.user.dto.mapper.UserMapper;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import io.jsonwebtoken.JwtException;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private static final Logger log = LoggerFactory.getLogger(AuthController.class);

    private final UserRepository userRepository;
    private final StationRepository stationRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final UserMapper userMapper;
    private final UserService userService;
    private final LoginEventRepository loginEventRepository;
    private final AnalyticsEventService analyticsEventService;
    private final RefreshTokenCookieWriter refreshTokenCookieWriter;
    private final MobiliSecurityRefreshSettings refreshSettings;
    


    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@RequestBody LoginRequest request, HttpServletResponse response) {
        log.info("[Login] Tentative de connexion pour login={}", request.getLogin());

        // UserService.registerUser stocke le login normalisé (trim + lowercase) — sans la même
        // normalisation ici, une casse/espace différent au login (ex. autofill qui capitalise,
        // copier-coller mobile) échoue avec "Identifiant incorrect" alors que le compte existe
        // (feedback testeurs : connexion impossible juste après inscription).
        String normalizedLogin = request.getLogin() != null ? request.getLogin().trim().toLowerCase() : null;
        var userOpt = userRepository.findByLogin(normalizedLogin);
        if (userOpt.isEmpty()) {
            return loginAsStation(request, response);
        }

        User user = userOpt.get();

        boolean isLegacyGareAccount = user.getStation() != null
                && user.getRoles().stream()
                        .anyMatch(r -> r.getName() == com.mobili.backend.module.user.role.UserRole.GARE);
        if (isLegacyGareAccount) {
            log.warn("[Login] Ancien compte chef de gare refusé: login={}", request.getLogin());
            analyticsEventService.record(AnalyticsEventType.FAILED_LOGIN, user.getId(),
                    "{\"reason\":\"LEGACY_GARE_ACCOUNT\"}");
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                    "Ce type de compte ne se connecte plus avec un identifiant personnel. Utilisez le code de la gare (ex. GAR-XXXXX) et son mot de passe.");
        }

        if (!user.isEnabled()) {
            log.warn("[Login] Compte désactivé: userId={}, login={}", user.getId(), user.getLogin());
            analyticsEventService.record(AnalyticsEventType.FAILED_LOGIN, user.getId(),
                    "{\"reason\":\"ACCOUNT_DISABLED\"}");
            throw new MobiliException(
                    MobiliErrorCode.ACCESS_DENIED,
                    "Compte inactif : en attente de validation par un administrateur, ou compte suspendu. Réessayez après activation.");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            log.warn("[Login] Mot de passe incorrect pour login={}", request.getLogin());
            analyticsEventService.record(AnalyticsEventType.FAILED_LOGIN, user.getId(),
                    "{\"reason\":\"BAD_PASSWORD\"}");
            throw new MobiliException(MobiliErrorCode.INVALID_CREDENTIALS, "Mot de passe incorrect.",
                    Map.of("password", "Mot de passe incorrect."));
        }

        loginEventRepository.save(new LoginEvent(user.getId(), user.getLogin()));
        log.info("[Login] Connexion réussie: userId={}, login={}, roles={}",
                user.getId(), user.getLogin(),
                user.getRoles().stream().map(r -> r.getName().name()).toList());

        String token = jwtService.generateToken(user);
        refreshTokenCookieWriter.write(response, user);
        return ResponseEntity.ok(new AuthResponse(token, user.getLogin(), user.getId(), null));
    }

    /**
     * Délivre un jeton d’accès à partir du cookie httpOnly (même hôte d’API que le login) —
     * utile quand l’utilisateur ouvre l’appli “Business” (autre origine) après connexion
     * sur l’appli voyage.
     */
    @PostMapping("/refresh")
    public ResponseEntity<AuthResponse> refresh(HttpServletRequest request) {
        String raw = getRefreshCookieValue(request);
        if (raw == null || raw.isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        try {
            if (!jwtService.isRefreshTokenType(raw) || jwtService.isTokenExpired(raw)) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }
            var userOpt = userRepository.findByLogin(jwtService.extractUsername(raw));
            if (userOpt.isEmpty() || !userOpt.get().isEnabled()) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }
            User u = userOpt.get();
            String access = jwtService.generateToken(u);
            return ResponseEntity.ok(new AuthResponse(access, u.getLogin(), u.getId(), null));
        } catch (JwtException | IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(HttpServletResponse response) {
        refreshTokenCookieWriter.clear(response);
    }

    private String getRefreshCookieValue(HttpServletRequest request) {
        Cookie[] cookies = request.getCookies();
        if (cookies == null) {
            return null;
        }
        for (Cookie c : cookies) {
            if (refreshSettings.getCookieName().equals(c.getName())) {
                return c.getValue();
            }
        }
        return null;
    }

    @PostMapping(value = "/register", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public ProfileDTO register(
            @RequestPart("user") @Valid RegisterDTO dto,
            @RequestPart(value = "avatar", required = false) MultipartFile avatar) {

        User user = userMapper.toEntity(dto);
        User savedUser = userService.registerUser(user, avatar);
        return userMapper.toProfileDto(savedUser);
    }

    /**
     * Inscription société de transport : dirigeant (compte) + fiche compagnie sans compte « voyageur »
     * intermédiaire. Connexion immédiate (JWT + cookie refresh), comme un login.
     */
    @PostMapping(value = "/register-company", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse registerCompany(
            @RequestPart("company") @Valid RegisterCompanyPublicDTO dto,
            @RequestPart(value = "logo", required = false) MultipartFile logo,
            @RequestPart("kycFront") MultipartFile kycFront,
            @RequestPart("kycBack") MultipartFile kycBack,
            HttpServletResponse response) {

        User saved = userService.registerCompanyPublic(dto, logo, kycFront, kycBack);
        String token = jwtService.generateToken(saved);
        refreshTokenCookieWriter.write(response, saved);
        loginEventRepository.save(new LoginEvent(saved.getId(), saved.getLogin()));
        return new AuthResponse(token, saved.getLogin(), saved.getId(), Boolean.TRUE);
    }
    /**
     * Inscription chauffeur **covoiturage** : pièce d’identité recto + verso + date de fin de validité.
     */
    @PostMapping(value = "/register-carpool-chauffeur", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public ProfileDTO registerCarpoolChauffeur(
            @RequestPart("user") @Valid RegisterCarpoolChauffeurDTO dto,
            @RequestPart("idFront") MultipartFile idFront,
            @RequestPart("idBack") MultipartFile idBack,
            @RequestPart("driverPhoto") MultipartFile driverPhoto,
            @RequestPart("vehiclePhoto") MultipartFile vehiclePhoto) {

        User saved = userService.registerCarpoolChauffeur(dto, idFront, idBack, driverPhoto, vehiclePhoto);
        return userMapper.toProfileDto(saved);
    }


    private ResponseEntity<AuthResponse> loginAsStation(LoginRequest request, HttpServletResponse response) {
        var stationOpt = stationRepository.findByCode(request.getLogin());
        if (stationOpt.isEmpty()) {
            log.warn("[Login] Identifiant non trouvé (ni utilisateur ni gare): {}", request.getLogin());
            analyticsEventService.record(AnalyticsEventType.FAILED_LOGIN, null, "{\"reason\":\"NOT_FOUND\"}");
            throw new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Identifiant incorrect.",
                    Map.of("login", "Identifiant incorrect."));
        }

        var station = stationOpt.get();

        if (!station.isActive()) {
            log.warn("[Login] Gare désactivée: code={}", request.getLogin());
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED,
                    "Cette gare est désactivée. Contactez votre société.");
        }

        if (station.getPassword() == null
                || !passwordEncoder.matches(request.getPassword(), station.getPassword())) {
            log.warn("[Login] Mot de passe gare incorrect pour code={}", request.getLogin());
            analyticsEventService.record(AnalyticsEventType.FAILED_LOGIN, null, "{\"reason\":\"BAD_PASSWORD\"}");
            throw new MobiliException(MobiliErrorCode.INVALID_CREDENTIALS, "Mot de passe incorrect.",
                    Map.of("password", "Mot de passe incorrect."));
        }

        String token = jwtService.generateStationToken(station);
        return ResponseEntity.ok(new AuthResponse(token, station.getCode(), station.getId(), null));
    }
}