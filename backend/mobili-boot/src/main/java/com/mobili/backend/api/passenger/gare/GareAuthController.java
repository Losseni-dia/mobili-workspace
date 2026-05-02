package com.mobili.backend.api.passenger.gare;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import com.mobili.backend.infrastructure.security.auth.RefreshTokenCookieWriter;
import com.mobili.backend.module.station.dto.GarePreviewResponse;
import com.mobili.backend.module.station.dto.GareSelfRegisterRequest;
import com.mobili.backend.module.station.service.GareSelfRegistrationService;
import com.mobili.backend.module.user.dto.login.AuthResponse;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/v1/auth/registration")
@RequiredArgsConstructor
public class GareAuthController {

    private final GareSelfRegistrationService gareSelfRegistrationService;
    private final RefreshTokenCookieWriter refreshTokenCookieWriter;
    private final UserRepository userRepository;

    @GetMapping("/gare/preview")
    public GarePreviewResponse previewGare(@RequestParam("code") String code) {
        return gareSelfRegistrationService.preview(code);
    }

    @PostMapping("/gare")
    public ResponseEntity<AuthResponse> registerGare(
            @Valid @RequestBody GareSelfRegisterRequest body,
            HttpServletResponse response) {
        AuthResponse created = gareSelfRegistrationService.register(body);
        if (created.getToken() != null && created.getUserId() != null) {
            userRepository.findById(created.getUserId()).ifPresent((User u) -> refreshTokenCookieWriter.write(response, u));
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }
}
