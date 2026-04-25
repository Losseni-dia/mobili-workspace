package com.mobili.backend.module.station.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.HttpStatus;

import com.mobili.backend.module.station.dto.GarePreviewResponse;
import com.mobili.backend.module.station.dto.GareSelfRegisterRequest;
import com.mobili.backend.module.station.service.GareSelfRegistrationService;
import com.mobili.backend.module.user.dto.login.AuthResponse;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/v1/auth/registration")
@RequiredArgsConstructor
public class GareAuthController {

    private final GareSelfRegistrationService gareSelfRegistrationService;

    @GetMapping("/gare/preview")
    public GarePreviewResponse previewGare(@RequestParam("code") String code) {
        return gareSelfRegistrationService.preview(code);
    }

    @PostMapping("/gare")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse registerGare(@Valid @RequestBody GareSelfRegisterRequest body) {
        return gareSelfRegistrationService.register(body);
    }
}
