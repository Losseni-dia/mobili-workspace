package com.mobili.backend.module.routing.exception;

/**
 * Levée UNIQUEMENT quand un fournisseur d'itinéraire répond explicitement qu'aucun itinéraire
 * n'existe pour la paire origine/destination donnée (ex. code "NoRoute" chez Mapbox) — jamais
 * pour une erreur réseau, un timeout ou une erreur HTTP 5xx générique, qui doivent remonter
 * telles quelles (voir DirectionsOrchestratorService : seule cette exception déclenche la
 * bascule vers un autre fournisseur, une panne réseau transitoire ne doit jamais déclencher un
 * appel doublé vers un second fournisseur payant).
 */
public class NoRouteFoundException extends RuntimeException {
    public NoRouteFoundException(String message) {
        super(message);
    }
}
