# Journal des changements (Mobili)

Le format s’inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Les entrées regroupent surtout le **dépôt** (docs + code) plutôt qu’une numérotation de version sémantique, tant qu’il n’y a pas de release nommée.

## [2026-04-25]

### Added

- **Migrations** : **Flyway** (`V1`–`V3`), dépendance Maven **`flyway-database-postgresql`** (compatibilité PostgreSQL 15+ / 18) ; colonne partenaire **`covoiturage_solo_pool`**, ajustement contraintes inbox.
- **Admin** : **annonces** → **`/admin/communication`** ; API **`POST /v1/admin/partner-communications`** (inbox dirigeants + chauffeurs covoiturage KYC approuvés pour les ciblages *tous* / *pool*), type `MOBILI_ADMIN_INFO_PARTNER`.
- **Covoiturage (conducteur particulier)** : espace Angular **`/covoiturage/*`** (shell, accueil, publication, console *piloter* partagée avec `/chauffeur`), API **`CovoiturageSoloTripController`**, partenaire pool technique ; garde **`covoiturageSoloGuard`**.
- **Covoiturage — scanner** : route **`/covoiturage/scan`**, composant partagé avec la gare (`TicketScannerComponent`) ; côté backend, **`verifyAndUseTicket`** : un **CHAUFFEUR** ne valide que les billets rattachés à **son** organisateur covoit. ou à **son** partenaire (lignes compagnie).

### Changed

- Retrait des anciens `ApplicationRunner` de migration SQL au profit de Flyway.
- **Admin** : en-têtes allégés sur la page annonces ; `pageDesc` admin masqué si vide (selon pages).

### Notes (non bloquant)

- **Paiement / payout covoiturage** (J+1, tronçon) : cadrage métier et implémentation à planifier — voir [README](README.md) (F43).

## [2026-04-24]

### Added

- Documentation : section **Démo locale (FedaPay & ngrok)** et ce fichier `CHANGELOG.md`.
- Suivi des fonctionnalités (README) : **F24** (écrans admin extra), **F32** (tarifs par tronçons), **F33** (console chauffeur), **F34** (design system & navigation).
- Métier backend : persistance `TripSegmentFare` et champ `legFares` sur les trajets ; API chauffeur sous `/v1/trips/{tripId}/driver/...`.
- Shells Angular : `UserShell`, `PartnerShell`, `AdminShell` ; route `/chauffeur` (console).
- En-tête public : liens **directs** vers vues d’ensemble (plus de listes déroulantes de navigation).
- Partenaire : colonne **code chauffeur** (ID trajet) avec copie dans la liste des voyages.
- i18n affichage : locale **fr** côté Angular.

### Changed

- Refonte visuelle (tokens Sass, `data-panel`, pages profil / réservations / chauffeur, etc.).

### Notes (non bloquant)

- **F31** (libération de siège après descente) reste planifié ; se rapproche de la console chauffeur + règles booking.

## [2026-04-23] et avant

- Recherche multi-arrêts (F30), pages accueil / résultats, doc `docs/recherche-segments.md` — voir le [README](README.md) et la table de suivi.
