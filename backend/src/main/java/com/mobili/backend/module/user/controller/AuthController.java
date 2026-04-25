package com.mobili.backend.module.user.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.security.token.JwtService;
import com.mobili.backend.module.admin.entity.LoginEvent;
import com.mobili.backend.module.admin.repository.LoginEventRepository;
import com.mobili.backend.module.analytics.entity.AnalyticsEventType;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.user.dto.ProfileDTO;
import com.mobili.backend.module.user.dto.RegisterCarpoolChauffeurDTO;
import com.mobili.backend.module.user.dto.RegisterDTO;
import com.mobili.backend.module.user.dto.login.AuthResponse;
import com.mobili.backend.module.user.dto.login.LoginRequest;
import com.mobili.backend.module.user.dto.mapper.UserMapper;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private static final Logger log = LoggerFactory.getLogger(AuthController.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final UserMapper userMapper;
    private final UserService userService;
    private final LoginEventRepository loginEventRepository;
    private final AnalyticsEventService analyticsEventService;


    @PostMapping("/login")
    public AuthResponse login(@RequestBody LoginRequest request) {
        log.info("[Login] Tentative de connexion pour login={}", request.getLogin());

        var userOpt = userRepository.findByLogin(request.getLogin());
        if (userOpt.isEmpty()) {
            log.warn("[Login] Utilisateur non trouvé: {}", request.getLogin());
            analyticsEventService.record(AnalyticsEventType.FAILED_LOGIN, null, "{\"reason\":\"NOT_FOUND\"}");
            throw new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Utilisateur non trouvé");
        }

        User user = userOpt.get();

        if (!user.isEnabled()) {
            log.warn("[Login] Compte désactivé: userId={}, login={}", user.getId(), user.getLogin());
            analyticsEventService.record(AnalyticsEventType.FAILED_LOGIN, user.getId(), "{\"reason\":\"ACCOUNT_DISABLED\"}");
            throw new MobiliException(
                    MobiliErrorCode.ACCESS_DENIED,
                    "Compte inactif : en attente de validation par un administrateur, ou compte suspendu. Réessayez après activation.");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            log.warn("[Login] Mot de passe incorrect pour login={}", request.getLogin());
            analyticsEventService.record(AnalyticsEventType.FAILED_LOGIN, user.getId(), "{\"reason\":\"BAD_PASSWORD\"}");
            throw new MobiliException(MobiliErrorCode.INVALID_CREDENTIALS, "Mot de passe incorrect");
        }

        loginEventRepository.save(new LoginEvent(user.getId(), user.getLogin()));
        log.info("[Login] Connexion réussie: userId={}, login={}, roles={}",
                user.getId(), user.getLogin(),
                user.getRoles().stream().map(r -> r.getName().name()).toList());

        String token = jwtService.generateToken(user);
        return new AuthResponse(token, user.getLogin(), user.getId(), null);
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
}