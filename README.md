# Mobili

Plateforme de **mobilité interurbaine** (réservation, billetterie, partenaires, paiement, rôles voyageur / partenaire / chauffeur / admin, gare & scanner).  
**Cible** : lancement en Afrique, en commençant par la **Côte d’Ivoire**.

Ce document sert de **mémoire projet** : vision, environnement, règles de qualité, backlog prioritaire et **suivi des fonctionnalités**.  
**À jour** : chaque nouvelle fonctionnalité livrée doit compléter la [table de suivi](#suivi-des-fonctionnalités) et, si besoin, une sous-section dédiée.  
**Dernière révision documentaire** : **25 avril 2026** (Docker : `docker-compose`, `backend/Dockerfile`, variables d’environnement, profils). Détails datés : [CHANGELOG](CHANGELOG.md).

### Résumé des évolutions récentes (code)

- **Docker** : [`docker-compose.yml`](docker-compose.yml) (PostgreSQL + build de l’API), [`backend/Dockerfile`](backend/Dockerfile) ; variables en [§ Docker](#docker) et [`application.yml`](backend/src/main/resources/application.yml).
- **Bagages** : politique par **voyage** (cabine / soute inclus, max soute en plus par passager, tarif supplément) ; **réservation** avec `extraHoldBags` et surtaxe ; **conducteur** : `GET /v1/trips/{id}/driver/luggage-summary` + carte UI sur la console. Migration **Flyway `V8`**.
- **Espaces intégrés (shells)** : `/my-account/*`, `/partenaire/*`, `/admin/*` et **`/gare/*`** (responsable gare) passent par des *shells* (sidebar + barre sup.) ; le header public n’encombre pas les espaces connectés.
- **Gare (responsable)** : espace dédié sous **`/gare`** (accueil, messages compagnie, scanner, profil, notifications, canal voyage d’un trajet) ; garde-fous **`gareOperationsGuard`** tant que le compte n’est pas validé / opérations autorisées par le partenaire.
- **Partenaire — gares** : CRUD gares rattachées à la compagnie (`/partenaire/gares`, création de comptes **responsable gare**), filtrage des réservations par gare côté API quand c’est pertinent.
- **Communication compagnie ↔ gares** : fils de discussion **collectifs** (tout le réseau) ou **ciblés** (gares choisies) — UI **`/partenaire/company-messages`** et **`/gare/company-messages`**, API **`/v1/partner-gare-com/**` ; notifications type inbox pour les acteurs concernés.
- **Notifications** : **inbox** (liste, lecture) et **canal de trajet** (fil par `tripId`) côté voyageur, partenaire et gare — avec **SSE** côté backend pour le rafraîchissement (en-têtes CORS adaptés) ; bannière / accès rapide possible selon l’espace.
- **Auth** : parcours **`/auth/inscription`** (choix profil) et **`/auth/register-gare`** (inscription responsable gare via **code compagnie** + prévisualisation gares) en complément de l’inscription voyageur.
- **UI** : design system partagé (Sass : `frontend/src/app/styles/_variables.scss`, `_mixins.scss`, `_data-panel.scss` ; `frontend/src/styles.scss`).
- **Navigation** : liens **directs** vers tableaux de bord — pas de gros menus déroulants dans le header public pour les espaces principaux.
- **Métier** : tarification **par tronçons** (`legFares` / `TripSegmentFare`) ; réservation segmentée (`boardingStopIndex` / `alightingStopIndex`, `BookingResponseDTO` enrichi).
- **Chauffeur** : **`/chauffeur`** (console terrain) + API `/v1/trips/{tripId}/driver/...` (`chauffeurGuard`).
- **Covoiturage (conducteur particulier, hors compagnie)** : shell **`/covoiturage/*`** (accueil, publication trajet, **même** console *piloter* que `/chauffeur`, **`/covoiturage/scan`**, notifications), garde **`covoiturageSoloGuard`** ; côté API trajets covoit. solo, partenaire technique **pool** (`covoiturageSoloPool` sur `partners`, bootstrap `CovoiturageSoloPartnerBootstrap`) ; vérification billet : **`/gare/scan`** (responsable gare) et **`/covoiturage/scan`** (même composant), avec contrôle **périmètre chauffeur** côté `TicketService`.
- **Base de données** : **Flyway** (migrations `V1` … `V8+` dans `backend/src/main/resources/db/migration/`) — schéma de référence idempotent, contraintes inbox, colonnes partenaire pool, **bagages** (`V8`) ; **obligatoire** : dépendance Maven **`org.flywaydb:flyway-database-postgresql`** (sinon erreur *Unsupported Database* sur PostgreSQL 15+ / 18) ; `baseline-on-migrate` pour bases déjà remplies. Les anciens `ApplicationRunner` de migration SQL (transport_type, CHECK) sont retirés au profit de Flyway.
- **Admin — annonces** : menu **« Annonces »** → **`/admin/communication`** ; envoi d’informations vers la **inbox** des comptes **dirigeants** (`Partner.owner`) +, pour les envois *Tous* / *Pool covoiturage*, des **chauffeurs covoiturage au KYC `APPROVED`** (pas le simple booléen d’inscription) ; type de notification `MOBILI_ADMIN_INFO_PARTNER` ; `POST /v1/admin/partner-communications` (`AdminPartnerCommunicationController`).
- **i18n** : locale **fr** pour dates / formats.

---

## Vision produit (mémo)

### En une phrase

Mobili permet de **rechercher**, **réserver** et **payer** des trajets interurbains, avec des **partenaires** qui publient des lignes, une **billetterie** (tickets / QR), un volet **gare** (scanner), et une **administration**.

### Utilisateurs

| Rôle        | Rôle métier principal                          |
|------------|-------------------------------------------------|
| Voyageur   | Recherche, réservation, paiement, billets      |
| Partenaire | Publication trajets, réservations clients    |
| Chauffeur  | Opérations terrain (selon implémentation)    |
| Admin      | Utilisateurs, partenaires, supervision         |
| Gare       | Espace **responsable gare** : accueil, messages compagnie, **scanner**, profil, notifications, canal trajet (selon garde-fous) |

### Priorité métier à court terme (critique)

1. **Trajets multi-arrêts & recherche** *(voir F30 — **PARTIEL**, validé local avril 2026)*  
   Exemple : ligne **Abidjan → Issia** passant par **Divo, Gagnoa, Lakota**.  
   Un voyageur **Abidjan → Gagnoa** doit voir :
   - les offres couvrant explicitement ce segment ;
   - **et** les trajets **Abidjan → Issia** qui **passent par** Gagnoa (même véhicule / même course), tant que le segment demandé est couvert.

2. **Descente en cours de route & siège libéré**  
   Quand un client **descend avant la terminus**, le siège doit redevenir **réservable** pour un autre passager **à partir du point de descente** (segments suivants), sans surbooking ni incohérence d’inventaire.

---

## Stack & environnement de développement

| Composant   | Détail habituel                          |
|------------|-------------------------------------------|
| Backend    | Spring Boot, YAML, **PostgreSQL** local, **Flyway** (migrations), **`flyway-database-postgresql`** recommandé |
| Frontend   | Angular, `ng serve` → **http://localhost:4200** |
| API        | **http://localhost:8080** (préfixe `/v1` côté client selon config) |
| Paiement   | **FedaPay sandbox** ; webhooks via **ngrok** en dev |
| CI         | **GitHub** prévu ; pipeline à brancher plus tard |
| Données    | **Dev uniquement** pour l’instant ; pas de données réelles / prod en local tant que la politique n’est pas formalisée |
| Secrets    | Fichiers **`.env` hors dépôt** (ou gestionnaire de secrets) — à durcir avant prod |

### Commandes utiles (racine logique)

```bash
# Backend (depuis ./backend)
mvn test

# Frontend (depuis ./frontend)
npm run test -- --watch=false
npm run build
ng serve
```

<a id="docker"></a>

## Docker (PostgreSQL + API)

Fichiers : [`docker-compose.yml`](docker-compose.yml) à la racine, [`backend/Dockerfile`](backend/Dockerfile). Les noms d’attributs côté Spring sont ceux de [`application.yml`](backend/src/main/resources/application.yml).

<a id="docker-root-env"></a>

### Fichier **`.env`** à la racine (non versionné)

`docker compose` charge automatiquement le fichier **`.env`** placé **à côté** de `docker-compose.yml`. **Créer** ce fichier (secrets locaux) avec au minimum :

```env
SPRING_PROFILES_ACTIVE=dev
JWT_SECRET=
FEDAPAY_SECRET_KEY=
FEDAPAY_WEBHOOK_SECRET=
DB_PASSWORD=mobili
```

Optionnel : `API_PORT`, `POSTGRES_PORT` (voir le compose). Ne pas commiter (voir [`.gitignore`](.gitignore)).

### Prérequis

- **Docker Engine** + **Docker Compose** (v2) installés.
- Aucun JAR à builder à la main : l’**image** compile le backend **pendant** `docker build`.

### Que fait `docker compose` ?

1. Démarrer **PostgreSQL 16** (base `mobili`, utilisateur `mobili`, mot de passe = `DB_PASSWORD` dans `.env` ou `mobili` par défaut).
2. Construire et lancer l’**API** Spring Boot (port **8080**), avec :
   - **`DB_URL`** = `jdbc:postgresql://postgres:5432/mobili` (nom du service Docker, **pas** `localhost` — c’est l’hôte du conteneur `postgres` sur le réseau interne).
   - Variables **`SPRING_PROFILES_ACTIVE`**, **`JWT_SECRET`**, FedaPay, transmises au conteneur.
3. **Volumes nommés** : données PG + dossier **`/app/uploads`** (images uploadées) pour ne pas les perdre au `docker compose down` (tant qu’on ne supprime pas les volumes).

Le **frontend Angular** n’est **pas** dans ce compose (vous le lancez avec `ng serve` en local, ou un build Nginx / hébergeur statique en prod). L’app pointe l’API via [`app.env.config.ts`](frontend/src/app/app.env.config.ts) : en local navigateur, **`http://localhost:8080/v1`** reste valable.

### Marche à suivre (première utilisation)

1. À la **racine** du dépôt : **`.env`** présent, avec les variables indiquées au début de cette section **Docker** (encadré d’exemple).
2. `docker compose up --build`  
   (première exécution = build Maven + image, quelques minutes).
3. Ouvrir `http://localhost:8080/v1/trips` pour vérifier l’API.
4. Lancer le front : `cd frontend && npm i && ng serve` → `http://localhost:4200`.

### Points d’attention (important)

| Sujet | Détail |
|--------|--------|
| **`.env` local `backend/.env` vs racine** | `docker compose` lit le **`.env` à côté de `docker-compose.yml`**. Le compose **fixe** `DB_URL` et `DB_USERNAME` pour l’API (service `postgres`) ; seul **`DB_PASSWORD`** vient en général du **`.env` racine**. En dev **sans** Docker, `application.yml` a des **défauts** (user `postgres`, base `mobili_db` sur `localhost:5432`) : il suffit en principe de **`DB_PASSWORD`**. Sous **Docker**, les variables **injectées par le compose** (URL vers le service `postgres`, user `mobili`) priment. |
| **FedaPay / webhooks** | Même règle qu’en [§ Démo locale](#démo-locale) : l’extérieur doit atteindre `POST /v1/payments/callback` (ngrok, domaine, etc.). L’URL du callback est celle **visible depuis Internet**, pas celle interne Docker. |
| **CORS** | En `dev`, les origines `localhost:4200` sont dans `application-dev.yml` / `MobiliCorsSettings`. En **acc/prod** derrière un domaine, mettre à jour `application-*.yml` ou des variables (voir [README backend — profils](backend/README.md)). |
| **Profil Spring dans Docker** | Par défaut `SPRING_PROFILES_ACTIVE=dev` dans `.env`. Pour une image type recette, utiliser `acc` ou `prod` et les bons CORS. |
| **Stop / données** | `docker compose down` : les **volumes** `mobili_pgdata` et `mobili_uploads` **restent** sauf si `docker compose down -v`. |

### Commandes utiles

```bash
docker compose up -d --build     # lancer en arrière-plan
docker compose logs -f api        # journal de l’API
docker compose down              # arrêter (volumes conservés)
docker compose down -v           # tout supprimer y compris les données (destructif)
```

### Évolution / prod

- Pousser les **mêmes images** sur un registry ; sur le serveur, fournir un **`.env` ou secrets** (Kubernetes secrets, PaaS, etc.) et la même logique d’environnement.
- **HTTPS** géré en général par un **reverse proxy** (Traefik, Nginx, cloud load balancer) devant l’API.
- Pour **packager le front** dans l’écosystème : image **Nginx** `COPY` du résultat de `ng build` — à ajouter plus tard si besoin.

---

<a id="demo-locale"></a>

### Démo locale (FedaPay & ngrok)

Objectif : payer en **sandbox FedaPay** avec un backend sur `localhost`, alors que FedaPay doit appeler un **webhook** accessible publiquement (pas `localhost`).

1. **Variables d’environnement (backend)** — fichier **`.env`** à la racine de `backend/` (ou outil équivalent) : en principe **`DB_PASSWORD`** (URL et utilisateur par défaut : `postgres` + base `mobili_db` — voir [`application.yml`](backend/src/main/resources/application.yml) ; `DB_URL` / `DB_USERNAME` seulement si ton PostgreSQL local diffère), plus **`JWT_SECRET`**, **`FEDAPAY_SECRET_KEY`**, **`FEDAPAY_WEBHOOK_SECRET`**.
2. **Démarrer l’API** : depuis `backend/`, `.\mvnw.cmd spring-boot:run` (ou `mvn spring-boot:run`) — **port 8080** par défaut.
3. **Exposer 8080 avec ngrok** (ex. binaire installé dans `C:\ngrok` sous Windows) :
   - `C:\ngrok\ngrok.exe http 8080`  
   - Noter l’URL **HTTPS** fournie (ex. `https://abc123.ngrok-free.app`).
4. **URL de webhook à configurer** côté FedaPay (ou variables internes pointant vers l’URL publique) :  
   **`{URL_NGROK}/v1/payments/callback`** — endpoint `POST` correspondant à [`PaymentController`](backend/src/main/java/com/mobili/backend/module/payment/fedaPay/controller/PaymentController.java) (`/callback`).
5. **Frontend** : `ng serve` sur **http://localhost:4200** ; l’app pointe l’API vers **http://localhost:8080/v1** en local ([`app.env.config.ts`](frontend/src/app/app.env.config.ts)). Après le retour de paiement, l’écran **succès** peut appeler `POST /v1/payments/verify/{bookingId}` si le webhook n’a pas pu atteindre le PC (comportement déjà géré côté client).

Côté **téléphone** (tester la **console chauffeur** ou un retour de paiement mobile), ngrok sur **8080** suffit pour le backend ; pour une SPA servie ailleurs que `localhost:4200`, on peut en plus exposer le port 4200 avec un second tunnel si besoin.

---

## Règles de qualité (obligatoires pour avancer proprement)

### Objectif

Chaque fonctionnalité livrée doit être :

1. **Testée dans le navigateur** (minimum actuel : **Chrome** ; viser aussi **vue mobile** / responsive pour l’objectif **mobile-first**).
2. **Couvert par des tests automatiques** quand c’est pertinent (objectif : **les deux** à terme).
3. **Documentée** dans ce README ([table de suivi](#suivi-des-fonctionnalités) + notes si besoin).

### Checklist navigateur (par feature)

À remplir / cocher avant de considérer la feature « terminée » pour la session :

- [ ] Scénario principal utilisateur (étapes claires)
- [ ] Cas d’erreur visible (message ou état UI, pas seulement la console)
- [ ] Chrome desktop
- [ ] Vue **mobile** (DevTools ou device réel) sur les écrans touchés
- [ ] Compte / rôle adapté (voyageur, partenaire, admin, etc.)

### Mini-rapport post-lot (copier-coller)

```
Feature : …
Branche / commit : …
Backend : mvn test → OK/KO
Frontend : npm test + build → OK/KO
Navigateur : Chrome + mobile (oui/non) — URLs : …
Checklist : (1) … (2) … → OK/KO
Limites connues : …
Suite : …
```

### CI / pipeline

- **Maintenant** : pas de blocage CI obligatoire ; exécuter **localement** `mvn test` et `npm run test` + `npm run build` avant de passer à la suite.
- **Ensuite** : pipeline GitHub qui **échoue la PR** si les tests ou le build cassent.

---

## Mobile : Capacitor, Ionic, ou natif ?

| Option | Intérêt | Inconvénients / quand l’éviter |
|--------|---------|--------------------------------|
| **Capacitor** (recommandé ici) | Réutilise **100 %** l’**Angular** actuel ; WebView + plugins (caméra, splash, status bar) ; un seul code pour web + coques stores. | Même dette web (perf proche d’un navigateur) ; CORS / URL d’API à **configurer** (prod + origines `capacitor://` / `ionic://` si besoin). |
| **Ionic** | Souvent **confondu** avec « app native » : en réalité **Ionic** (composants UI) + **Capacitor** = stack très courante. Vous n’avez **pas** à « réécrire en Ionic » : soit vous gardez votre UI Angular, soit vous importez des composants Ionic **plus tard** si besoin. | Refonte UI si migration massive vers composants Ionic sans nécessité métier. |
| **PWA** | Zéro store, déploiement rapide, même code. | Moins d’exposition App Store / Play, APIs système parfois limitées. |
| **Natif Kotlin / Swift** | Perf maximale, UX « 100 % plateforme », accès fin aux APIs. | **Deux** codebases (ou équipe mobile dédiée), délais longs, **hors sujet** tant que le produit web n’est pas stabilisé et rentable. **À envisager seulement** après traction, contraintes stores pointues, ou dette de perf démontrée. |

**Conclusion pour Mobili** : **Capacitor** est le meilleur prochain pas : pas de réécriture, alignement sur le monorepo actuel, ouverture stores quand l’offre le mérite.

### Feuille de route Capacitor (suggestion)

1. **Prérequis** : `npm run build` stable ; API déployée en **HTTPS** ; variables d’environnement frontend pour **URL API prod** (pas de `localhost` en dur côté build mobile).
2. **Installation** : `npm i @capacitor/core @capacitor/cli` ; `npx cap init` (nom + bundle id) dans `frontend/`.
3. **Sync** : `npx cap add android` (et/ou `ios` sur macOS) ; `npx cap copy` / `npx cap sync` après chaque `ng build`.
4. **Réseau** : ajuster `SecurityConfig` **CORS** : en prod, `allowedOrigins` = domaine web **+** origines applicatives (selon la doc Capacitor pour la version iOS/Android utilisée) — **indispensable** sinon les appels API depuis l’app native échoueront.
5. **Plugins utiles** : `@capacitor/splash-screen`, `status-bar` ; `barcode` / `camera` si le scan QR sort du pur web.
6. **Auth** : token JWT déjà côté client — vérifier **stockage sécurisé** (préférer **Capacitor Preferences** / Keychain plutôt que `localStorage` seul sur long terme).
7. **Tests** : Android Studio / Xcode ; signing pour bêta (TestFlight, Play interne) avant public.
8. **Store** : fiches Play / App Store, politique de confidentialité, compte légide (côté Côte d’Ivoire / UE selon cible).

**Ordre par rapport au déploiement** : voir [§ Sécurité, robustesse et ordre de déploiement](#sécurité-robustesse-et-ordre-de-déploiement).

---

## Sécurité, robustesse et ordre de déploiement

### Synthèse d’audit (expert)

- **Points solides** : mots de passe **BCrypt** ; API **stateless JWT** ; `BookingController` force `userId` depuis le **Principal** (pas d’emprunt d’identité via le corps JSON) ; webhook FedaPay avec **comparaison secrète** ; règles `SecurityConfig` / `@PreAuthorize` assez granulaires sur les chemins sensibles.
- **À traiter avant une mise en production publique** (non exhaustif) :
  - **CORS** : aujourd’hui limité à `localhost:4200` — **insuffisant** pour un domaine de prod et pour **Capacitor** ; externaliser `allowed-origins` (profil `prod` + liste configurable).
  - **Fichiers statiques** `/uploads/**` en `permitAll` : toute personne connaissant une URL peut tenter d’y accéder — en prod, **signer** les URLs, **rôles** de lecture, ou **proxy** authentifié.
  - **CSRF** désactivé (normal pour API JWT) : s’assurer qu’**aucun cookie de session** ne porte d’actes sensibles sans protection équivalente.
  - **Validation & limites** : rate limiting (login, `POST /bookings`, paiement), en-têtes de sécurité HTTP (`SecurityHeaders`), dépendances à suivre (`mvn dependency:check` / `npm audit`).
  - **Secrets** : le fichier **`.env`** ne doit **jamais** être versionné (déjà dans `backend/.gitignore`) — utiliser le gestionnaire de secrets de l’hébergeur en prod.
- **Cohérence** : règles bagages côté **service** (plafond, prix) alignées sur le front de réservation ; conduire des **tests** sur parcours paiement + wallet.

### Faut-il finir le « durcissement » avant le packaging mobile ?

- **Oui, partiellement** : le **coût** d’un build Capacitor est faible, mais **inutile** de publier en store si l’**API n’est pas en HTTPS** avec **CORS** et secrets propres. On peut en parallèle : (1) déployer l’API en **staging** + front web sur un domaine ; (2) brancher un **binaire Android** interne (debug) sur cette API ; (3) **ne pas** viser le store public tant que l’audit minimum (CORS, uploads, rate limit, secrets) n’est pas fait.
- **Non** : il n’est pas obligatoire d’attendre le **100 %** des features métier pour **prouver** le flux mobile en interne — tant que l’on ne **commercialise** pas l’app.

### Mobile-first (web)

- **Mobile-first** sur le **web Angular** : prioritaire (UX, formulaires, layout) — inchangé.

<a id="sécurité-robustesse-et-ordre-de-déploiement"></a>

---

## Backlog global (ordre logique de travail)

| Phase | Epic | Description courte |
|-------|------|-------------------|
| **A** | Modèle multi-arrêts | `Trip` + arrêts ordonnés (ville, ordre, temps si besoin) |
| **A** | Segments & matching | Savoir si une ligne Abidjan→Issia « couvre » Abidjan→Gagnoa |
| **A** | API recherche | Paramètres `from` / `to` / date → résultats documentés |
| **B** | Réservation par segment | Montée / descente + sièges liés au segment |
| **B** | Libération siège | Descente anticipée → siège disponible sur segments suivants |
| **B** | Anti surbooking | Contraintes / verrous selon modèle de données |
| **C** | Front recherche & détail | Résultats clairs (direct vs même bus / segment) |
| **D** | Paiement & scanner | Cohérence FedaPay + validation ticket avec nouvelles règles |
| **E** | Industrialisation | CI GitHub, secrets, envs, puis **Capacitor** si besoin store |

**Décision produit à trancher** : la « descente » est-elle déclenchée par **chauffeur / partenaire / admin** uniquement, ou aussi par le **voyageur** dans l’app ? (impact UX + permissions.)

---

## Cartographie technique (référentiel repo)

Base : [`frontend/src/app/app.routes.ts`](frontend/src/app/app.routes.ts). Toutes les URLs ci-dessous sont relatives à `http://localhost:4200`.  
**Guards** : `authGuard` = connecté ; `adminGuard` = admin ; `chauffeurGuard` = chauffeur ; `partnerOperationsGuard` = partenaire avec **opérations** autorisées (dirigeant) ; `gareOperationsGuard` = compte gare **validé** par le partenaire (sinon accès limité : pas scanner / pas trajets, etc. selon les routes) ; `covoiturageSoloGuard` = espace **conducteur covoiturage particulier** (profil / KYC selon règles).

**Préfixe de shell** : les lignes `my-account`, `partenaire` (sauf `partenaire/register`), `admin` et **`covoiturage`** sont des routes **parent** avec `router-outlet` enfant. Les composants indiqués sont les **vues** ; le *shell* est dans le parent (`user-shell`, `partner-shell`, `admin-shell`, `covoiturage-shell`).

### Routes Angular (écrans)

| Chemin | Écran / module | Guard | Fichier (lazy ou statique) |
|--------|----------------|-------|----------------------------|
| `/` | Accueil (liste / recherche trajets) | Public | `features/public/home/home.component` |
| `/search-results` | Résultats de recherche | Public | `features/public/search-results/search-results.component` |
| `/auth/login` | Connexion | Public | `features/auth/login/login.component` |
| `/auth/inscription` | Choix du type d’inscription (voyageur / gare) | Public | `features/auth/inscription-chooser/inscription-chooser.component` |
| `/auth/register` | Inscription voyageur | Public | `features/auth/register/register.component` |
| `/auth/register-gare` | Inscription **responsable gare** (code compagnie) | Public | `features/auth/register-gare/register-gare.component` |
| `/my-account` | *Shell* voyageur (redirige → `profile`) | `authGuard` | `features/user/user-shell/user-shell.component` |
| `/my-account/profile` | Tableau de bord / profil | `authGuard` | `features/user/profile/profile.component` |
| `/my-account/profile-edit` | Édition profil | `authGuard` | `features/user/profile/user-edit/user-edit.component` |
| `/my-account/bookings` | Mes réservations | `authGuard` | `features/user/my-bookings/my-bookings.component` |
| `/my-account/my-tickets` | Mes billets | `authGuard` | `features/bookings/my-tickets/my-tickets.component` |
| `/my-account/notifications` | Boîte de réception (alertes) | `authGuard` | `features/notifications/inbox-page/inbox-page.component` |
| `/my-account/trip-channel/:tripId` | Fil **canal voyage** (commentaires/infos trajet) | `authGuard` | `features/notifications/trip-channel-page/trip-channel-page.component` |
| `/partenaire/register` | Devenir partenaire (hors shell) | `authGuard` | `features/auth/register-partner/register-partner.component` |
| `/partenaire` | *Shell* partenaire (redirige → `dashboard`) | `authGuard` | `features/partenaire/partner-shell/partner-shell.component` |
| `/partenaire/dashboard` | Dashboard partenaire | `authGuard` | `features/partenaire/dashboard/dashboard.component` |
| `/partenaire/settings` | Paramètres société | `authGuard` | `features/partenaire/partner-edit/partner-edit.component` |
| `/partenaire/trips` | Liste des trajets (col. **code chauffeur** + copie) | `authGuard` | `features/partenaire/trip-management/trip-management.component` |
| `/partenaire/add-trip` | Publier un trajet (dont **tarifs par tronçon** si renseignés) | `authGuard` | `features/partenaire/trip-management/trip-add/add-trip.component` |
| `/partenaire/edit-trip/:id` | Modifier un trajet | `authGuard` | `features/partenaire/trip-management/trip-edit/trip-edit.component` |
| `/partenaire/bookings` | Réservations clients | `authGuard` + `partnerOperationsGuard` (selon route) | `features/partenaire/my-customers-bookings/booking-list.component` |
| `/partenaire/gares` | **Liste / gestion des gares** (comptes responsables) | `authGuard` | `features/partenaire/station-list/station-list.component` |
| `/partenaire/company-messages` | **Messages compagnie ↔ gares** (fils) | `authGuard` | `features/shared/company-messages/company-messages.component` |
| `/partenaire/notifications` | Inbox (partenaire) | `authGuard` + `partnerOperationsGuard` | `features/notifications/inbox-page/inbox-page.component` |
| `/partenaire/trip-channel/:tripId` | Canal voyage | `authGuard` + `partnerOperationsGuard` | `features/notifications/trip-channel-page/trip-channel-page.component` |
| `/gare` | *Shell* responsable gare (redirige → `accueil`) | `authGuard` | `features/gare/gare-shell/gare-shell.component` |
| `/gare/accueil` | Accueil gare (aperçu, liens) | `authGuard` | `features/gare/gare-home/gare-home.component` |
| `/gare/company-messages` | **Messages compagnie** (même composant que partenaire, périmètre gare) | `authGuard` | `features/shared/company-messages/company-messages.component` |
| `/gare/scan` | Scanner / validation billet | `authGuard` + `gareOperationsGuard` | `features/gare/scanner/scanner.component` |
| `/gare/profil` | Fiche gare côté responsable | `authGuard` + `gareOperationsGuard` | `features/gare/gare-home/gare-profile/gare-profile.component` |
| `/gare/compte` | Édition compte (profil user) | `authGuard` + `gareOperationsGuard` | `features/user/profile/user-edit/user-edit.component` |
| `/gare/notifications` | Inbox (gare) | `authGuard` + `gareOperationsGuard` | `features/notifications/inbox-page/inbox-page.component` |
| `/gare/trip-channel/:tripId` | Canal voyage | `authGuard` + `gareOperationsGuard` | `features/notifications/trip-channel-page/trip-channel-page.component` |
| `/chauffeur` | Console chauffeur (trajet, arrêts, passagers) | `chauffeurGuard` | `features/chauffeur/driver-console/driver-console.component` |
| `/covoiturage` | *Shell* covoiturage (conducteur particulier, redirige → `accueil`) | `covoiturageSoloGuard` | `features/covoiturage/covoiturage-shell/covoiturage-shell.component` |
| `/covoiturage/accueil` | Accueil covoiturage | `covoiturageSoloGuard` | `features/covoiturage/covoiturage-home/covoiturage-home.component` |
| `/covoiturage/publier` | Publier un trajet covoiturage | `covoiturageSoloGuard` | `features/covoiturage/covoiturage-publish/covoiturage-publish.component` |
| `/covoiturage/piloter` | Console trajet (réutilise `driver-console`) | `covoiturageSoloGuard` | `features/chauffeur/driver-console/driver-console.component` |
| `/covoiturage/scan` | Scanner billet (QR) — **même** composant que gare | `covoiturageSoloGuard` | `features/gare/scanner/scanner.component` (`TicketScannerComponent`) |
| `/covoiturage/notifications` | Inbox (covoiturage) | `covoiturageSoloGuard` | `features/notifications/inbox-page/inbox-page.component` |
| `/admin` | *Shell* admin (redirige → `dashboard`) | `adminGuard` | `features/admin/admin-shell/admin-shell.component` |
| `/admin/dashboard` | Admin — tableau de bord | `adminGuard` | `features/admin/admin-dashboard/admin-dashboard` |
| `/admin/analyse-app` | Analyse / analytics app | `adminGuard` | `features/admin/admin-app-analytics/admin-app-analytics` |
| `/admin/metier` | Vue métier | `adminGuard` | `features/admin/admin-business/admin-business` |
| `/admin/users` | Admin — utilisateurs | `adminGuard` | `features/admin/admin-users/admin-users` |
| `/admin/partners` | Admin — partenaires | `adminGuard` | `features/admin/admin-partners/admin-partners` |
| `/admin/communication` | Admin — **annonces** (dirigeants + chauffeurs KYC selon filtre) | `adminGuard` | `features/admin/admin-communication/admin-communication` (lazy) |
| `/booking/trip/:id` | Choix sièges + passagers (segment) | `authGuard` | `features/bookings/booking-trip/booking-trip.component` |
| `/booking/confirmation/:id` | Récap + paiement FedaPay | `authGuard` | `features/bookings/booking-confirmation/booking-confirmation.component` |
| `/payment/success` | Retour paiement (polling statut réservation) | `authGuard` | `features/payment/payment-success/payment-success.component` |
| `/**` | Inconnue → redirection accueil | — | `redirectTo: ''` |

### API REST (Spring) — préfixe client `/v1`

Les URLs ci-dessous sont le suffixe après la base configurée (ex. `http://localhost:8080/v1`). Le contrôleur paiement est mappé sur `v1/payments` (sans slash initial) : en pratique l’URL complète est alignée avec `/v1/payments/...`.

| Contrôleur | Base `@RequestMapping` | Rôle métier (résumé) |
|------------|------------------------|----------------------|
| `AuthController` | `/v1/auth` | `POST /login`, `POST /register` |
| `UserReadController` | `/v1/auth` | `GET /` (liste profils, admin), `GET /{id}`, `GET /me` |
| `UserWriteController` | `/v1/users` | `PATCH /{id}/toggle-status`, `PUT /{id}` (multipart profil) |
| `TripReadController` | `/v1/trips` | `GET /`, `GET /{id}` (incl. `legFares`), `GET /{id}/stops`, `GET /search`, `GET /my-trips` |
| `TripWriteController` | `/v1/trips` | `POST /`, `PUT /{id}`, `DELETE /{id}` (multipart) ; corps `TripRequestDTO` avec `legFares` optionnel |
| `TripDriverController` | `/v1/trips/{tripId}/driver` | `POST /start`, `POST /departures`, `GET /luggage-summary`, `GET /stops/{stopIndex}/alightings`, `POST /tickets/{ticketNumber}/alighted` — rôles chauffeur / partenaire / gare / admin |
| `BookingController` | `/v1/bookings` | CR réservation, confirm wallet, sièges occupés (paramètres segment), partenaire |
| `TicketController` | `/v1/tickets` | création, liste user, annulation, vérification numéro |
| `PaymentController` | `v1/payments` | `POST /checkout/{bookingId}`, `POST /verify/{bookingId}` (retour FedaPay), `POST /callback` (webhook) |
| `PartnerWriteController` | `/v1/partners` | création / mise à jour / toggle / suppression partenaire |
| `PartenerReadController` | `/v1/partners` | liste, détail, `GET /my-company` |
| `PartnerDashboardController` | `/v1/partenaire/dashboard` | `GET /stats` (aperçu activité) |
| `StationController` | `/v1/partenaire/stations` | CRUD gares, stats, création utilisateur gare — **PARTNER** / **GARE** / **ADMIN** (méthodes ciblées) |
| `GareAuthController` | `/v1/auth/registration` | `GET /gare/preview?code=…` (préinscription) ; `POST /gare` (inscription responsable gare) — parties **publiques** si déclarées en `permitAll` (voir `SecurityConfig`) |
| `PartnerGareComController` | `/v1/partner-gare-com` | fils & messages compagnie ↔ gares (liste, création fil, message, etc.) — **PARTNER** / **GARE** / **ADMIN** |
| `InboxNotificationController` | `/v1/inbox` | notifications utilisateur (liste, lecture) |
| `InboxSseController` | `/v1/inbox` *(flux SSE)* | rafraîchissement temps quasi réel (incl. en-têtes CORS `Last-Event-ID`) |
| `TripChannelController` | `/v1/trips/{tripId}/channel` | messages du **canal voyage** (rôles selon règles) |
| `AdminController` | `/v1/admin` | utilisateurs, partenaires, stats, statuts |
| `AdminPartnerCommunicationController` | `/v1/admin` | `GET/POST /partner-communications` — annonces inbox (`MOBILI_ADMIN_INFO_PARTNER`) |
| *(Flyway)* | `classpath:db/migration` | `V1`–`V8+` : schéma, contraintes, inbox, affectations, **bagages**… |

---

## Suivi des fonctionnalités

**Légende statut** : `OK` livré et validé selon les règles ci-dessus · `EN_COURS` · `PLANIFIE` · `PARTIEL` (à compléter / dette connue)

**Colonnes « Lien »** : route Angular et/ou groupe d’endpoints API associés (voir [cartographie](#cartographie-technique-référentiel-repo)).

| ID | Domaine | Fonctionnalité | Lien FE | Lien API | Statut | Tests auto | Checklist navigateur | Notes |
|----|---------|----------------|---------|----------|--------|------------|----------------------|-------|
| F01 | Public | Accueil & découverte trajets | `/` | `GET /trips` | PARTIEL | `trip.service.spec.ts` | **OK** (local 2026-04-23) | Filtre live sans bouton (debounce) ; catalogue si départ+arrivée vides — [doc recherche](./docs/recherche-segments.md) |
| F02 | Public | Résultats recherche | `/search-results` | `GET /trips/search` | PARTIEL | idem + page API | **OK** (local 2026-04-23) | Query `departure`/`arrival`/`date` ; rétrocompat `from`/`to` — [doc](./docs/recherche-segments.md) |
| F03 | Auth | Connexion JWT + profil `/me` | `/auth/login` | `POST /auth/login`, `GET /auth/me` | PARTIEL | Partiel (FE/BE) | À systématiser | Durcissements sécurité API déjà en place |
| F04 | Auth | Inscription voyageur (multipart) | `/auth/register` | `POST /auth/register` | PARTIEL | Minimal | À systématiser | |
| F05 | Compte | Profil lecture (dashboard shell) | `/my-account/profile` | `GET /auth/me` | PARTIEL | Minimal | À systématiser | `UserShell` : aperçu, stats, prochains voyages |
| F06 | Compte | Édition profil + avatar | `/my-account/profile-edit` | `PUT /users/{id}` | PARTIEL | Minimal | À systématiser | Intégré au shell |
| F07 | Compte | Mes réservations | `/my-account/bookings` | `GET /bookings/user/{userId}` | PARTIEL | Minimal | À systématiser | Filtres, segment, libellés villes (DTO) |
| F08 | Compte | Mes billets | `/my-account/my-tickets` | `GET /tickets/user/{userId}` | PARTIEL | Minimal | À systématiser | Style ticket / shell |
| F09 | Réservation | Choix sièges & création réservation | `/booking/trip/:id` | `GET /bookings/trips/{id}/occupied-seats` (+ indices arrêt), `POST /bookings` | PARTIEL | Partiel | À systématiser | Segment (montée/descente) + `legFares` côté trip si configuré — voir F32 |
| F10 | Réservation | Récap & redirection paiement FedaPay | `/booking/confirmation/:id` | `GET /bookings/{id}` (champs `boardingCity`, `alightingCity`, `totalPrice`…), `POST /payments/checkout/{id}` | PARTIEL | Partiel | Sandbox + ngrok | |
| F11 | Paiement | Retour succès & synchro statut | `/payment/success` | `GET /bookings/{id}` (+ webhook `POST /payments/callback`) | PARTIEL | Partiel | Query `id` + `status` | Polling borné côté FE |
| F12 | Partenaire | Inscription société | `/partenaire/register` | `POST /partners` | PARTIEL | Minimal | À systématiser | |
| F13 | Partenaire | Dashboard & stats | `/partenaire/dashboard` | `GET /partenaire/dashboard/stats` | PARTIEL | Minimal | À systématiser | |
| F14 | Partenaire | Fiche / paramètres société | `/partenaire/settings` | `GET /partners/my-company`, `PUT /partners/{id}` | PARTIEL | Minimal | À systématiser | |
| F15 | Partenaire | CRUD trajets (liste, création, édition) | `/partenaire/trips`, `/add-trip`, `/edit-trip/:id` | `GET/POST/PUT/DELETE /trips`, `GET /trips/my-trips` | PARTIEL | Minimal | À systématiser | Liste : **code chauffeur** (ID) copiable ; création/édit : `legFares` — voir F32 |
| F16 | Partenaire | Réservations clients | `/partenaire/bookings` | `GET /bookings/partner/my-bookings`, actions associées | PARTIEL | Minimal | À systématiser | |
| F17 | Partenaire | Blocage sièges manuel (vente gare) | `/partenaire/trips` (action depuis gestion trajets) | `POST /bookings/partner/deactivate-seats` | PARTIEL | Minimal | À systématiser | Voir `trip-management.component.ts` |
| F18 | Gare | Scanner / utilisation billet | `/gare/scan` | `PATCH /tickets/verify/{ticketNumber}` | PARTIEL | Minimal | Rôles chauffeur / gare (si validée) / admin / partenaire | `gareOperationsGuard` |
| F19 | Admin | Tableau de bord | `/admin/dashboard` | `GET /admin/stats` | PARTIEL | Minimal | `adminGuard` | `AdminShell` (sidebar) |
| F20 | Admin | Gestion utilisateurs | `/admin/users` | `GET /admin/users`, `PATCH /admin/users/{id}/status` | PARTIEL | Minimal | `adminGuard` | |
| F21 | Admin | Gestion partenaires | `/admin/partners` | `GET /admin/partners`, `PATCH /admin/partners/{id}/toggle` | PARTIEL | Minimal | `adminGuard` | |
| F22 | Billets | Annulation billet (client) | *(depuis Mes billets)* | `PATCH /tickets/{id}/cancel` | PARTIEL | Partiel | À systématiser | Contrat FE aligné sur `PATCH` |
| F23 | Réservation | Confirmation paiement interne (wallet) | *(partenaire / back-office)* | `PATCH /bookings/{id}/confirm` | PARTIEL | Partiel | À documenter parcours | Distinct de FedaPay |
| F24 | Admin | Analyse app / métier (extra) | `/admin/analyse-app`, `/admin/metier` | *selon impl.* | PARTIEL | — | `adminGuard` | Routes présentes dans `app.routes.ts` |
| **F30** | **Métier** | **Recherche multi-arrêts (segment sur ligne longue)** | `/`, `/search-results` | `GET /trips`, `GET /trips/search` + chaîne villes (`moreInfo`) | **PARTIEL** | BE : `TripServiceSearchTest` ; FE : `trip.service.spec.ts` | **OK** (local 2026-04-23) | Livré et validé en local (segment sur `moreInfo`) ; reste : e2e, mobile-first systématique, jeux de données réalistes — [doc](./docs/recherche-segments.md) |
| **F31** | **Métier** | **Libération siège après descente anticipée** | *(à définir)* | `Booking` / `Ticket` + nouveaux endpoints | **PLANIFIE** | — | — | Idem |
| **F32** | **Métier** | **Tarifs par tronçons** (`legFares` / `TripSegmentFare`) | Création/édit trajet, `GET /trips/{id}` | `PUT/POST /trips` avec `legFares` ; `TripPricingService` | **PARTIEL** | À renforcer | À systématiser | Somme tronçons vs prorata ; prévisualisation côté service |
| **F33** | **Chauffeur** | **Console terrain** (départs, passagers à descendre) | `/chauffeur` | `TripDriverController` : `/v1/trips/{tripId}/driver/...` | **PARTIEL** | Minimal | `chauffeurGuard` | ID trajet (souvent aligné sur « code » partenaire) ; ngrok possible pour test mobile |
| **F34** | **UX** | **Design system & navigation directe** | Toute l’app | — | **PARTIEL** | — | **OK** (local 2026-04) | Tokens Sass, `data-panel`, pas de dropdown principal vers sous-menus |
| **F35** | **Gare** | **Espace responsable gare (shell, accueil, garde-fous)** | `/gare/*` | rôles + `GareProfileEnricher` / champs `gareOperationsEnabled` | **PARTIEL** | Minimal | `gareOperationsGuard` | Scanner & profil bloqués tant que le partenaire n’a pas validé la gare |
| **F36** | **Partenaire** | **Gestion des gares & comptes responsables** | `/partenaire/gares` | `GET/POST/… /v1/partenaire/stations` | **PARTIEL** | Minimal | À systématiser | Création utilisateur gare, rattachement partenaire |
| **F37** | **Com** | **Messages compagnie ↔ gares** (fils collectif / ciblé) | `/partenaire/company-messages`, `/gare/company-messages` | `GET/POST /v1/partner-gare-com/...` | **PARTIEL** | Minimal | À systématiser | Ciblage gares, anti-doublon titre fil, notifs inbox `PARTNER_GARE_COM_MESSAGE` |
| **F38** | **Notif** | **Inbox + SSE** | `/my-account/notifications`, homologues partenaire/gare | `GET /v1/inbox/...` + flux SSE | **PARTIEL** | Partiel | À systématiser | CORS en-têtes `Last-Event-ID` côté API |
| **F39** | **Notif** | **Canal de trajet** (fil lié à un `tripId`) | `/.../trip-channel/:tripId` | `GET/POST /v1/trips/{id}/channel/...` | **PARTIEL** | Minimal | À systématiser | Rôles selon règles `TripChannelService` / `SecurityConfig` |
| **F40** | **Auth** | **Inscription & préinscription gare (code compagnie)** | `/auth/inscription`, `/auth/register-gare` | `GET/POST /v1/auth/registration/...` | **PARTIEL** | Partiel (tests BE récents) | À systématiser | Workflow validation partenaire possible (`accountPending`) |
| **F41** | **Infra** | **Migrations Flyway PostgreSQL** | — | `db/migration` (`V1`+… incl. `V8` bagages), `pom.xml` : `flyway-database-postgresql` | **PARTIEL** | — | — | Bases existantes : `baseline-on-migrate` ; V2 idempotent (sans effacement de données) |
| **F42** | **Admin** | **Annonces (inbox partenaire / chauffeurs KYC)** | `/admin/communication` | `POST /v1/admin/partner-communications` | **PARTIEL** | — | `adminGuard` | Segments BROADCAST (COMPANIES / ALL / COVOITURAGE_POOL) ou sélection fiches partenaire ; `MOBILI_ADMIN_INFO_PARTNER` |
| **F43** | **Covoiturage** | **Espace conducteur particulier (shell, publier, piloter, scanner)** | `/covoiturage/*` | `CovoiturageSoloTripController`, pool partenaire, `TicketService#verifyAndUseTicket` (périmètre chauffeur) | **PARTIEL** | — | `covoiturageSoloGuard` | Même `driver-console` en *piloter* ; **`/covoiturage/scan`** = `TicketScannerComponent` (comme gare) ; côté API un **CHAUFFEUR** ne valide que les billets de **ses** trajets (covoit. = organisateur, sinon même partenaire) — règles **payout** (J+1, etc.) hors périmètre actuel. |
| **F44** | **Métier** | **Bagages (politique voyage, supplément réservation, synthèse conducteur)** | Résa `/booking/trip/:id`, part. création/édit trajet, `/chauffeur` | `Trip` (quotas) ; `POST /bookings` (`extraHoldBags`) ; `GET …/driver/luggage-summary` | **OK** (code) | À renforcer | Partiel | Style transporteur (Flix-like) — à valider navigateur + contrats de test |

> **Convention** : à chaque merge ou fin de lot, mettre à jour la ligne (statut, colonnes tests, lien PR ou date). Ajouter une **nouvelle ligne** pour chaque nouvelle capacité visible utilisateur. Si un écran n’appelle pas encore l’API indiquée, corriger la colonne **Notes** plutôt que d’inventer un lien.

---

## Structure du dépôt

- `backend/` — API Spring ([README backend](./backend/README.md)), **Dockerfile** pour l’image JAR
- `frontend/` — SPA Angular ([README frontend](./frontend/README.md))
- [`docker-compose.yml`](docker-compose.yml) — PostgreSQL + API (voir [§ Docker](#docker))
- **`.env` à la racine** (non versionné) — modèle d’en-tête [§ Docker — fichier `.env`](#docker-root-env)
- `docs/` — notes techniques (ex. [recherche multi-arrêts](./docs/recherche-segments.md))
- [`CHANGELOG.md`](CHANGELOG.md) — historique de documentation / livraisons par date

---

## Licence & contact

À compléter selon ton choix (propriétaire, MIT, etc.).
