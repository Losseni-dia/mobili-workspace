package com.mobili.backend.infrastructure.security;

/**
 * Chemins HTTP <strong>relatifs au {@code server.servlet.context-path}</strong> ({@code /v1}) —
 * pour {@code authorizeHttpRequests} et filtres servlet (Spring Security ne répète pas le context-path).
 * <p>
 * URL publique complète côté client = context-path + ces segments (ex. {@code /v1/auth/login}).
 */
public final class MobiliApiPaths {

    /** Documentaire : préfixe URL publique (déjà pris en charge par Spring Boot via {@code context-path}). */
    public static final String PUBLIC_API_PREFIX = "/v1";

    /** Auth, inscription, refresh cookie. */
    public static final String AUTH = "/auth";
    public static final String AUTH_REGISTRATION = AUTH + "/registration/**";

    /** Catalogue trajets, canal public, QR chauffeur. */
    public static final String TRIPS = "/trips";
    public static final String TRIPS_GLOB = TRIPS + "/**";
    public static final String TRIPS_CHAUFFEUR = TRIPS + "/chauffeur/**";
    public static final String TRIPS_WILD_DRIVER = TRIPS + "/*/driver/**";
    public static final String TRIPS_WILD_CHANNEL_MESSAGES = TRIPS + "/*/channel/messages";
    public static final String TRIPS_MY_TRIPS = TRIPS + "/my-trips";

    /**
     * Paiement — webhooks/callbacks serveur-à-serveur (Stripe, FedaPay) : pas de
     * JWT MOBILI côté appelant, doivent rester {@code permitAll()} (l'authenticité
     * est vérifiée par signature Stripe / secret partagé FedaPay dans le contrôleur
     * lui-même, pas par Spring Security).
     */
    public static final String PAYMENTS_STRIPE_WEBHOOK = "/payments/stripe/webhook";
    public static final String PAYMENTS_FEDAPAY_CALLBACK = "/payments/fedapay/callback";

    /** Remboursement : action sensible, réservée aux admins. */
    public static final String PAYMENTS_REFUND = "/payments/refund/**";

    /** Espace compagnie / partenaire (préfixe API aligné sur les routes front {@code /partenaire/…}). */
    public static final String PARTENAIRE = "/partenaire";
    public static final String PARTENAIRE_DASHBOARD = PARTENAIRE + "/dashboard/**";
    public static final String PARTENAIRE_STATIONS = PARTENAIRE + "/stations/**";
    public static final String PARTENAIRE_CHAUFFEURS = PARTENAIRE + "/chauffeurs";
    public static final String PARTENAIRE_CHAUFFEURS_GLOB = PARTENAIRE_CHAUFFEURS + "/**";

    /** Communication partenaire–gare (scan, etc.). */
    public static final String PARTNER_GARE_COM = "/partner-gare-com/**";

    /** Covoiturage “solo” côté conducteur. */
    public static final String COVOITURAGE = "/covoiturage/**";


    /**
     * Candidature conducteur (ROLE_USER autorisé — pas encore ROLE_CHAUFFEUR à ce
     * stade).
     */
    public static final String COVOITURAGE_APPLY = "/covoiturage/profile/apply";

    
    public static final String INBOX = "/inbox/**";

    public static final String PARTNERS = "/partners";
    public static final String PARTNERS_GLOB = PARTNERS + "/**";
    public static final String PARTNERS_MY_COMPANY = PARTNERS + "/my-company";

    public static final String ADMIN = "/admin/**";

    public static final String BOOKINGS = "/bookings/**";
    public static final String TICKETS = "/tickets/**";

    /** Lecture authentifiée des médias sensibles (KYC, etc.) — jamais servis en statique public. */
    public static final String MEDIA_PRIVATE = "/media/private";

    private MobiliApiPaths() {
    }
}
