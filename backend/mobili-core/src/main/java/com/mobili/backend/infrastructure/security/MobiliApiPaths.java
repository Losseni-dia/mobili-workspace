package com.mobili.backend.infrastructure.security;

/**
 * Préfixes et chemins HTTP exposés (monolithe, unique base {@code /v1}).
 * Utilisé par la configuration de sécurité dans {@code mobili-boot}. Phase 2 : mutualiser
 * les constantes d’URL avant d’y déplacer d’autres bâtis de domaine.
 */
public final class MobiliApiPaths {

    public static final String V1 = "/v1";

    /** Auth, inscription, refresh cookie. */
    public static final String AUTH = V1 + "/auth";
    public static final String AUTH_REGISTRATION = AUTH + "/registration/**";

    /** Catalogue trajets, canal public, QR chauffeur. */
    public static final String TRIPS = V1 + "/trips";
    public static final String TRIPS_GLOB = TRIPS + "/**";
    public static final String TRIPS_CHAUFFEUR = TRIPS + "/chauffeur/**";
    public static final String TRIPS_WILD_DRIVER = TRIPS + "/*/driver/**";
    public static final String TRIPS_WILD_CHANNEL_MESSAGES = TRIPS + "/*/channel/messages";
    public static final String TRIPS_MY_TRIPS = TRIPS + "/my-trips";

    /** Paiement (callback gateway). */
    public static final String PAYMENTS_CALLBACK = V1 + "/payments/callback";

    /** Espace compagnie / partenaire (préfixe API aligné sur les routes front {@code /partenaire/…}). */
    public static final String PARTENAIRE = V1 + "/partenaire";
    public static final String PARTENAIRE_DASHBOARD = PARTENAIRE + "/dashboard/**";
    public static final String PARTENAIRE_STATIONS = PARTENAIRE + "/stations/**";
    public static final String PARTENAIRE_CHAUFFEURS = PARTENAIRE + "/chauffeurs";
    public static final String PARTENAIRE_CHAUFFEURS_GLOB = PARTENAIRE_CHAUFFEURS + "/**";

    /** Communication partenaire–gare (scan, etc.). */
    public static final String PARTNER_GARE_COM = V1 + "/partner-gare-com/**";

    /** Covoiturage “solo” côté conducteur. */
    public static final String COVOITURAGE = V1 + "/covoiturage/**";

    public static final String INBOX = V1 + "/inbox/**";

    public static final String PARTNERS = V1 + "/partners";
    public static final String PARTNERS_GLOB = PARTNERS + "/**";
    public static final String PARTNERS_MY_COMPANY = PARTNERS + "/my-company";

    public static final String ADMIN = V1 + "/admin/**";

    public static final String BOOKINGS = V1 + "/bookings/**";
    public static final String TICKETS = V1 + "/tickets/**";

    /** Lecture authentifiée des médias sensibles (KYC, etc.) — jamais en statique public. */
    public static final String MEDIA_PRIVATE = V1 + "/media/private";

    private MobiliApiPaths() {
    }
}
