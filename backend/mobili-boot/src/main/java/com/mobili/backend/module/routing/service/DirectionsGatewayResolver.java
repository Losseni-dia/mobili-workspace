package com.mobili.backend.module.routing.service;

import com.mobili.backend.module.routing.enums.DirectionsProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Miroir structurel exact de PaymentGatewayResolver (module payment) — un simple annuaire,
 * jamais de logique de bascule ici (voir DirectionsOrchestratorService pour la bascule
 * Mapbox -> Google Maps).
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class DirectionsGatewayResolver {

    private final List<DirectionsProviderService> directionsProviderServices;

    /**
     * Recherche l'implémentation de DirectionsProviderService correspondant au provider donné.
     */
    public DirectionsProviderService resolve(DirectionsProvider provider) {
        return directionsProviderServices.stream()
                .filter(service -> service.getDirectionsProvider() == provider)
                .findFirst()
                .orElseThrow(() -> {
                    log.error("❌ Aucun DirectionsProviderService trouvé pour le provider : {}", provider);
                    return new IllegalArgumentException("Provider non supporté : " + provider);
                });
    }
}
