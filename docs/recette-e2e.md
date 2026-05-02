# Recette : navigateur manuel + E2E (smoke)

Ce fichier complète les **règles de qualité** décrites dans le [README racine](../README.md) : **recette navigateur**, **tests E2E automatiques légers**, et pistes UX.

---

## Tests E2E (Playwright) — voyageur

Emplacement : `frontend/e2e/`, configuration `frontend/playwright.config.ts`.

### Commandes (`frontend/`)

| Commande | Rôle |
|----------|------|
| `npm install` | une fois (déjà inclut `@playwright/test`) |
| `npx playwright install chromium` | une fois par machine ou après upgrade Playwright |
| `npm run e2e` | lance **`ng serve`** sur le port **4200** puis les scénarios (comportement par défaut) |
| `npm run e2e:business` | E2E **`mobili-business`** (port **4201**), config `playwright.business.config.ts` |
| `npm run e2e:all` | enchaîne **`e2e`** puis **`e2e:business`** (CI) |
| `npm run e2e:headed` | même chose avec fenêtre Chromium visible |

**Déjà un `ng serve` qui tourne ?** Pour réutiliser le serveur sans le relancer :

```bash
set PLAYWRIGHT_SKIP_WEBSERVER=1
npm run e2e
```

(PowerShell : `$env:PLAYWRIGHT_SKIP_WEBSERVER="1"`. Linux/macOS : `export PLAYWRIGHT_SKIP_WEBSERVER=1`.)

URL de base surchargeable :

```bash
set MOBILI_BASE_URL=http://localhost:4200
```

### Couverture actuelle

**Voyageur (`e2e/`)**

- Accueil : bloc héros (`data-testid="home-hero-title"`).
- Formulaire de recherche sur l’accueil.
- Page `/auth/login` : titre « Connexion ».
- **F30** : page `/search-results` — titre du segment (`departure` → `arrival`) via `data-testid="search-results-heading"` ; liste des trajets à valider avec API réelle ou recette manuelle.

**Mobili Business (`e2e-business/`, port 4201)**

- Page `/auth/login` : titre « Connexion ».

**Non couvert encore** : parcours bout-en-bout avec **API réelle** (recherche → réservation → paiement), vue mobile systématique.

---

## Checklist navigateur manuelle (par lot ou avant release)

À adapter selon les écrans modifiés ; base minimale :

- [ ] **Chrome desktop** — parcours concerné avec compte pertinent (voyageur / partenaire / gare / admin selon routes).
- [ ] **Vue mobile** — DevTools responsive ou téléphone réel sur les formulaires principaux (recherche, login, réservation si touchée).
- [ ] Erreurs **visibles pour l’utilisateur** (message ou état vide), pas seulement la console vide.
- [ ] Si l’API est requise : stack locale **PostgreSQL + backend 8080** + front (`ng serve`), ou environnement **recette** décrit dans le README (profils Spring, CORS).

---

## Finitions UX (rappel)

- Cohérence **espacements / typo** avec `src/app/styles/` (voir README frontend).
- **Focus** et libellés de champs pour l’accessibilité de base.
- Prévoir des **`data-testid`** sur les blocs critiques si vous étendez les E2E (évite les sélecteurs fragiles sur les classes CSS).

---

## CI

Sur les PR/push GitHub (`main` / `develop`), le workflow **Frontend E2E smoke** installe Chromium et exécute `npm run e2e:all` dans `frontend/` (voyageur puis Business).
