# Mobili — Frontend (Angular)

SPA du projet **Mobili**. Le détail produit, le **suivi des fonctionnalités** et le [CHANGELOG daté](../CHANGELOG.md) sont dans le [**README à la racine**](../README.md) du workspace parent lorsque le dépôt est cloné avec `backend/` + `frontend/`.

**Recherche trajets** : [docs/recherche-segments.md](../docs/recherche-segments.md) (paramètres API, accueil, résultats).

## État des espaces (routes)

- **Voyageur** : shell `user-shell` — profil, réservations, billets, **inbox** (`/my-account/notifications`), **canal trajet** (`/my-account/trip-channel/:tripId`).
- **Partenaire** : shell `partner-shell` — dashboard, **gares** (`/partenaire/gares`), **messages compagnie** (`/partenaire/company-messages`), trajets, réservations clients, notifications, canal voyage.
- **Gare (responsable)** : shell `gare-shell` — accueil, **mêmes messages compagnie** côté gare, scanner, profil, compte, notifications, canal (routes sous `/gare/...`) ; garde **`gareOperationsGuard`** tant que la gare n’est pas autorisée par le partenaire.
- **Chauffeur** : page pleine page `/chauffeur` (`driver-console`), garde `chauffeurGuard`.
- **Covoiturage (conducteur particulier)** : shell `covoiturage-shell` — accueil, publication, **même** `driver-console` en *piloter*, **scanner** **`/covoiturage/scan`**, notifications (routes sous **`/covoiturage/...`**) ; garde **`covoiturageSoloGuard`**. Même **composant** de scan que la gare (`TicketScannerComponent`).
- **Admin** : shell `admin-shell` — dashboard, analytics app, vue métier, utilisateurs, partenaires, **annonces** → **`/admin/communication`** (envoi d’informations vers inbox dirigeants / ciblage, selon règles backend).
- **Auth** : `/auth/inscription` (choix de parcours), `/auth/register-gare` (inscription responsable gare avec code compagnie).

## Styles & i18n

- Design system : `src/app/styles/_variables.scss`, `_mixins.scss`, `_data-panel.scss` ; global `src/styles.scss`.
- Locale **fr** : `LOCALE_ID` + `registerLocaleData` dans `app.config.ts`.

## Développement

```bash
ng serve
```

Navigateur : **http://localhost:4200/**. L’URL de l’API est configurée via les variables d’environnement (voir `app.env.config.ts` / `configuration.service.ts`).

## Build & tests

```bash
ng build
ng test
```

Tests **E2E (smoke)** avec [Playwright](https://playwright.dev/) : depuis `frontend/`, `npm run e2e` (voyageur, port 4200, `playwright.config.ts`) ; `npm run e2e:business` (Mobili Business, port 4201) ; `npm run e2e:all` pour les deux. Réutiliser un serveur déjà lancé : **`PLAYWRIGHT_SKIP_WEBSERVER=1`**. Détail : [docs/recette-e2e.md](../docs/recette-e2e.md).

---

Projet généré avec [Angular CLI](https://github.com/angular/angular-cli). Référence complète : [Angular CLI](https://angular.dev/tools/cli).
