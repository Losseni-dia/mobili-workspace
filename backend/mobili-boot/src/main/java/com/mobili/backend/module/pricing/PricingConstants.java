package com.mobili.backend.module.pricing;

/**
 * Seuils et taux du forfait client et de la commission compagnie — un seul endroit pour
 * toutes les valeurs numériques du barème, jamais recopiées ailleurs dans le code.
 * Voir BookingFeeService et CompanyCommissionService.
 */
public final class PricingConstants {

    private PricingConstants() {
    }

    // ── Forfait client (BookingFeeService) — bornes volontairement asymétriques ────────────
    /** total <= ce seuil -> CLIENT_FEE_LOW. */
    public static final double CLIENT_FEE_LOW_THRESHOLD = 3000;
    /** total >= ce seuil -> CLIENT_FEE_HIGH. Entre les deux seuils -> CLIENT_FEE_MID. */
    public static final double CLIENT_FEE_HIGH_THRESHOLD = 7000;

    public static final int CLIENT_FEE_LOW = 100;
    public static final int CLIENT_FEE_MID = 200;
    public static final int CLIENT_FEE_HIGH = 300;

    // ── Commission compagnie (CompanyCommissionService) — barème progressif par palier ────
    /** Tickets n°1 à ce nombre inclus, ce mois-ci pour la compagnie -> COMMISSION_RATE_TIER_1. */
    public static final long COMMISSION_TIER_1_MAX = 500;
    /** Tickets n°(TIER_1_MAX+1) à ce nombre inclus -> COMMISSION_RATE_TIER_2. Au-delà -> TIER_3. */
    public static final long COMMISSION_TIER_2_MAX = 2000;

    public static final double COMMISSION_RATE_TIER_1 = 0.09;
    public static final double COMMISSION_RATE_TIER_2 = 0.07;
    public static final double COMMISSION_RATE_TIER_3 = 0.05;

    // ── Contrainte structurelle réservation ─────────────────────────────────────────────────
    public static final int MAX_TICKETS_PER_BOOKING = 5;
}
