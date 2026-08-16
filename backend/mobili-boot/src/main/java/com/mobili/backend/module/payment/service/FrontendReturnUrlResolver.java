package com.mobili.backend.module.payment.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.mobili.backend.infrastructure.configuration.MobiliCorsSettings;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;

/**
 * Détermine l'URL du site web (Angular) vers laquelle rediriger le navigateur après un
 * paiement (Stripe success/cancel, retour FedaPay) — jamais l'API. Le domaine définitif n'est
 * pas encore figé (le site n'est pas toujours servi sur mobili.public.frontend-url selon
 * l'environnement de test) : on préfère donc l'en-tête Origin de la requête qui a initié le
 * paiement, quand elle correspond à une origine CORS déjà autorisée, pour s'adapter
 * automatiquement à l'endroit réel où le site est servi (localhost, IP de test, futur domaine
 * prod...) sans avoir à redéployer le backend à chaque changement. Repli sur
 * mobili.public.frontend-url si l'en-tête est absent, vide, ou non reconnu.
 */
@Component
@RequiredArgsConstructor
public class FrontendReturnUrlResolver {

    private final MobiliCorsSettings mobiliCorsSettings;

    @Value("${mobili.public.frontend-url}")
    private String defaultFrontendUrl;

    public String resolve(HttpServletRequest request) {
        String origin = request != null ? request.getHeader("Origin") : null;
        if (origin != null && !origin.isBlank() && mobiliCorsSettings.getAllowedOrigins().contains(origin)) {
            return origin;
        }
        return defaultFrontendUrl;
    }
}
