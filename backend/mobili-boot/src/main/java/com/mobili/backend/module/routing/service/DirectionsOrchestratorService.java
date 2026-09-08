package com.mobili.backend.module.routing.service;

import com.mobili.backend.module.routing.dto.DirectionsRequest;
import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.enums.DirectionsProvider;
import com.mobili.backend.module.routing.exception.NoRouteFoundException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;

/**
 * Seul endroit du module routing où vit la logique de bascule Mapbox -> Google Maps — le
 * resolver (DirectionsGatewayResolver) reste un simple annuaire, exactement comme
 * PaymentGatewayResolver ne fait jamais de fallback lui-même.
 *
 * La bascule ne se déclenche QUE sur NoRouteFoundException (Mapbox a répondu explicitement
 * "aucun itinéraire" pour cette paire de points) — jamais sur une erreur réseau/technique
 * générique (timeout, 5xx), qui remonte telle quelle sans tenter Google Maps : retenter
 * aveuglément sur un 2e fournisseur payant pour une panne réseau transitoire masquerait le
 * problème réel sans le résoudre, et doublerait le coût API pour rien.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class DirectionsOrchestratorService {

    private final DirectionsGatewayResolver directionsGatewayResolver;

    public DirectionsResult getDirectionsWithFallback(DirectionsRequest request) {
        try {
            DirectionsResult result = directionsGatewayResolver.resolve(DirectionsProvider.MAPBOX)
                    .getDirections(request);
            log.info("✅ Itinéraire calculé via Mapbox (fournisseur principal).");
            return result;
        } catch (NoRouteFoundException e) {
            log.warn("⚠️ Mapbox n'a trouvé aucun itinéraire, bascule vers Google Maps : {}", e.getMessage());
            DirectionsResult fallback = directionsGatewayResolver.resolve(DirectionsProvider.GOOGLE_MAPS)
                    .getDirections(request);
            log.info("✅ Itinéraire calculé via Google Maps (bascule après échec Mapbox).");
            return fallback;
        }
    }
}
