package com.mobili.backend.module.pricing.dto;

/**
 * Résultat du calcul de commission pour UN ticket : le taux appliqué (figé, traçable) et le
 * montant qui en découle (arrondi au FCFA supérieur).
 */
public record CommissionResult(double rate, int amount) {
}
