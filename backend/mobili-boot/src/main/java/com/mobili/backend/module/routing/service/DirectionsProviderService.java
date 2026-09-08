package com.mobili.backend.module.routing.service;

import com.mobili.backend.module.routing.dto.DirectionsRequest;
import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.enums.DirectionsProvider;

/**
 * Miroir structurel de PaymentService (module payment) : une implémentation par fournisseur
 * d'itinéraire, chacune s'identifiant via getDirectionsProvider(). Aucune logique de bascule
 * ici — voir DirectionsOrchestratorService pour la bascule Mapbox -> Google Maps.
 */
public interface DirectionsProviderService {

    /**
     * Calcule l'itinéraire entre origine et destination chez ce fournisseur.
     * @throws com.mobili.backend.module.routing.exception.NoRouteFoundException si le
     *         fournisseur ne trouve explicitement aucun itinéraire pour cette paire de points
     *         (jamais levée pour une erreur réseau/technique générique — celles-ci remontent
     *         telles quelles, sans être transformées en NoRouteFoundException).
     */
    DirectionsResult getDirections(DirectionsRequest request);

    /**
     * Retourne le fournisseur supporté par cette implémentation.
     */
    DirectionsProvider getDirectionsProvider();
}
