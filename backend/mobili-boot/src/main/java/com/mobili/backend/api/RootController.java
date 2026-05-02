package com.mobili.backend.api;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Point d’entrée HTTP racine : l’API REST vit sous {@code /v1}, pas sur {@code /}.
 */
@RestController
public class RootController {

    @GetMapping("/")
    public Map<String, String> root() {
        return Map.of(
                "service", "mobili-api",
                "api", "/v1",
                "health", "/actuator/health");
    }
}
