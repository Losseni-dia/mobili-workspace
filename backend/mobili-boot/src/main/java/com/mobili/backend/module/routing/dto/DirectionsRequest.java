package com.mobili.backend.module.routing.dto;

/**
 * Position d'origine (dernière position GPS connue du véhicule, envoyée par le client) et de
 * destination (résolue côté backend à partir du prochain arrêt non quitté — voir
 * TripRunService.nextStopCityOrNull) pour un calcul d'itinéraire/ETA.
 */
public record DirectionsRequest(
        double originLat,
        double originLng,
        double destinationLat,
        double destinationLng) {
}
