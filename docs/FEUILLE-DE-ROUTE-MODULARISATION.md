# Feuille de route — Mobili / Mobili Business (guide pas à pas)

Document **d’architecture & produit** : comment scinder l’offre **voyageur** (« Mobili ») et **acteurs pro** (compagnies, gares, covoit/chauffeur selon cadrage) **sans** tout réécrire.  
**Complète** le [ROADMAP.md](../ROADMAP.md) (priorités métier, déploiement) et le [README](../README.md) (vision, stack).  
**Dernière révision** : avril 2026.

---

## 1. But et principe unique

- **Un seul modèle métier** (réservation, trajets, partenaires, paiement) : pas de fork des entités ni des règles dans deux bases.
- **D’abord le produit** (deux expériences web / deux bundles) ; le **découpage de deux binaires Spring** n’intervient qu’en cas de **besoin** (équipe, SLO, isolation).
- S’appuyer sur l’**existant** : rôles `USER` / `PARTNER` / `GARE` / `CHAUFFEUR` / `ADMIN`, [SecurityConfig](../backend/mobili-boot/src/main/java/com/mobili/backend/infrastructure/security/SecurityConfig.java), [UserRole](../backend/mobili-boot/src/main/java/com/mobili/backend/module/user/role/UserRole.java), routes front dans [`app.routes.ts`](../frontend/src/app/app.routes.ts).

**Réf. discussions** : synthèse « harmonisée » (feuille de route + variante multi-modules / deux ECS) — c’est celle portée ici en étapes.

---

## 2. Avant toute branche lourde — valider le dépôt

À lancer **depuis la racine** du monorepo (`mobili/`) :

| Action | Commande | Résultat attendu |
|--------|----------|------------------|
| Tout (CI locale) | `npm run verify` | Backend : **Maven Wrapper** `mvn -B test` depuis `backend/` (reactor) ; deux builds Angular (`frontend` + `mobili-business`) ; `ng test` |
| Raccourci partiel | `npm run verify:backend` | `node scripts/backend-mvnw.mjs -B test` (évite une install Maven système sous Windows) |
| Build appli business seule | `npm run verify:frontend:business` | `ng build mobili-business` (dev) |
| Front build seul (voyageur) | `npm run verify:frontend` | Build dev app racine, sans seconde appli |
| API seule (dossier `backend/`) | `.\mvnw.cmd -B test` (Windows) · `./mvnw -B test` (Unix) · ou `node scripts/backend-mvnw.mjs -B test` depuis la racine | Compile + tests du reactor |
| Dev (deux onglets) | `cd frontend` puis `npm run start` (4200) et `npm run start:business` (4201) | API depuis `backend/` : `.\mvnw.cmd -pl mobili-boot -am spring-boot:run` (profil `dev`, port 8080) |



- Si `ng test` échoue faute d’environnement headless (Karma) : au minimum garder `verify:backend` + `verify:frontend` verts avant de merger une grosse refonte.

---

## 3. Phase 0 — Cadrage (0,5–2 j / atelier)

- [x] **Périmètre « Mobili Business »** : partenaire + gare ; covoit/chauffeur = **option** itérative (voir doc).
- [x] **Préfixes de routes** front et **préfixes API** : consignés dans [CADRAGE-PHASE-0.md](CADRAGE-PHASE-0.md).
- [x] **Hôtes** cibles décrits (à figer en DNS quand dispo).
- [x] Ligne dédiée **État des phases voyageur / Mobili Business** dans le [README racine](../README.md#phases-modularisation) (repère équipe · avril 2026).

**Livrable** : [CADRAGE-PHASE-0.md](CADRAGE-PHASE-0.md) (gel 2026-04-28).

---

## 4. Phase 1 — Produit : deux facades front (sans toucher le JAR d’abord)

**Objectif** : deux expériences (marque, navigation, build) en gardant **une** API.

- [x] **Bibliothèque** `mobili-shared` ([`projects/mobili-shared`](../frontend/projects/mobili-shared)) : point d’entrée public (`MOBILI_APP_PRODUCT`, `mobiliBusinessShellTitle` dans `app-kind.ts`) — **à enrichir** (HTTP, intercepteurs, modèles) par PR successives.
- [x] **Deuxième appli** `mobili-business` ([`projects/mobili-business`](../frontend/projects/mobili-business)) : shell minimal + import de la lib ; l’**appli voyageur** reste le projet `frontend` (racine `src/`) inchangé fonctionnellement.
- [x] **CORS** : ports **4200** + **4201** en [application-dev.yml](../backend/mobili-boot/src/main/resources/application-dev.yml) et [application-staging.yml](../backend/mobili-boot/src/main/resources/application-staging.yml).
- [x] **Dev** : `npm run start` (dossier `frontend/`) = port **4200** ; `npm run start:business` = port **4201** ([`package.json`](../frontend/package.json) racine appli `frontend`).

- [x] **Donnée partagée** : `CONFIGURATION_DATA` (URL API) dans [mobili-env.config.ts](../frontend/projects/mobili-shared/src/lib/mobili-env.config.ts) ; `ConfigurationService` matche `localhost:4200` / `4201` (host avec port) ; l’[app principale](../frontend/src/app/app.env.config.ts) réexporte pour compat.
- [x] **Alias TypeScript** `@mobili-app/*` → `src/app/*` ([tsconfig.json](../frontend/tsconfig.json)) pour charger les mêmes `features` / guards / interceptors.
- [x] **Routes** : [business.routes.ts](../frontend/projects/mobili-business/src/app/business.routes.ts) = auth (login, inscriptions) + `partenaire/*` + `gare/*` ; appli = `app.config` + mêmes interceptors HTTP.
- [x] **Styles** : [styles.scss](../frontend/projects/mobili-business/src/styles.scss) réimporte les styles globaux ; `includePaths` SASS `src` sur le projet business ([angular.json](../frontend/angular.json)).
- [x] **Bascule produit** : `partenaire/*` et `gare/*` **retirés** de l’[app.routes](../frontend/src/app/app.routes.ts) côté appli voyageur ; [redirect vers `businessWebBase`](../frontend/src/app/features/routing/redirect-to-business.component.ts) (voir [mobili-env.config](../frontend/projects/mobili-shared/src/lib/mobili-env.config.ts)). **Session** : origines différentes (ex. 4200 vs 4201) ⇒ **pas** de `localStorage` partagé — reconnexion sur le site Business ; futur : cookie domaine `.mobili.ci` ou SSO.
- [x] **Build** : `npm run verify` inclut `ng build mobili-business` (voir `package.json` racine). **Auth** : inchangé côté API (un seul `POST /v1/auth/login`).

**Livrable (état actuel)** : `npm run verify` ; **port 4201** = portail partenaire + gare **fonctionnel** (mêmes écrans que 4200) ; 4200 redirige les routes pro vers `businessWebBase`.

**Validation** : `npm run verify` ; en local : API `dev` sur 8080, `npm start` (4200) et `npm run start:business` (4201).

### 4.1 Clôture de la Phase 1 — deux niveaux (éviter le flou)

Quand on dit « on termine la Phase 1 avant d’enchaîner », il faut distinguer **le livrable code** (déjà atteint) des **prolongements recette / prod** (chantiers transverses, parfois longs).

| Sous‑phase | Contenu | Statut (à l’équipe) | Bloque-t-il la Phase 2 back ? |
|------------|---------|----------------------|---------------------------------|
| **1.0 — Front scindé (code)** | Deux apps, `mobili-shared`, `businessWebBase`, redirection 4200→`businessWebBase`, CORS recette, double build, tests | **Fait** dans le dépôt | **Non** — le découpage packages Java (Phase 2) est indépendant. |
| **1.1 — Auth / session** | **Backend + front livrés** : refresh JWT + cookie **httpOnly** ; intercepteurs identiques voyageur **et** Mobili Business. **À caler ensuite sur domaines** (*.mobili.ci*, `credentials`, `SameSite`) **au moment du DNS** ; en local deux origines ⇒ double login encore normal. | **Code clos** · recette hors localhost = chantier infra + cookie domain quand vous déployez | **Ne bloque pas** la Phase 2 back. |
| **1.2 — Déploiement** | S3 / CloudFront, secrets IAM — hors scope **code**. | Quand vous branchez l’infra | **Non** pour la suite code |

**Règle pratique** : considérer la **Phase 1.0** comme **terminée** côté dépôt dès `npm run verify` vert + comportement 4200/4201 validé. Ouvrir des tickets / branches séparés pour **1.1** (auth) et **1.2** (déploiement) afin de ne pas bloquer indéfiniment le démarrage de la **Phase 2** (structuration back).

**Ordre de priorité** si l’on veut « tout finir la Phase 1 » au sens recette : **1.2** (URL réelle + `businessWebBase`) pour tester en conditions réelles, puis **1.1** (session) car souvent le point bloquant en démo, pas l’inverse.

---

## 5. Phase 2 — Backend : modularité *dans* le monolithe (option, avant 2 exécutables)

**Objectif** : clarifier le code **sans** multiplier les process en local.

- [x] Couche **`com.mobili.backend.api.passenger`** (voyageur, catalogue, chauffeur/covoiturage, paiement…) · **`api.partner`** (compagnie, gares, écriture trajets…) · **`api.admin`** (ops admin) ; **domaines inchangés** sous `module.*`.
- [x] Module Maven **`mobili-core`** (constantes **`MobiliApiPaths`**, tests) + **`mobili-boot`** (application, **`SecurityConfig`**, contrôleurs, Flyway). Pas de deuxième JAR sans validation Phase 3.
- [x] Un seul **Flyway** dans **`mobili-boot`** ; une seule exécution de migrations (voir [`application.yml`](../backend/mobili-boot/src/main/resources/application.yml)).

**Livrable** : graphe de dépendances clair, PRs petites, tests verts.

---

## 6. Phase 3 — Deux exécutables Spring (seulement si le besoin est validé)

**Déclencheurs** : deux équipes, SLO différenciés, obligation d’isoler le blast radius, budget infra accepté (2 tâches Fargate, 2 images, 2 process en local).

- [ ] Module **`mobili-core`** : entités, repositories, services métiers partagés, génération JWT, filtre JWT, `UserDetailsService`.
- [ ] Application **`mobili-user-api`** : *uniquement* les `SecurityFilterChain` / contrôleurs du périmètre public + passager (attention aux `GET` publics, bookings, profil).
- [ ] Application **`mobili-business-api`** : partenaire, gare, (selon cadrage) covoit opérateur, etc.
- [ ] **Migrations** : *une* source de vérité Flyway — exécuter par **un** binaire désigné ou un **job** « migrator » ; éviter que les deux lancent `migrate` en concurrence.
- [ ] **Tests d’intégration** : scénarios couvrant **les deux** apps ou contrats d’API si clients séparés.

**Livrable** : deux JARs, pipelines CI de ton choix (build / push), doc des ports locaux (ex. 8080 / 8081).

---

## 7. Phase 4 — Hébergement (quand le split binaire est retenu)

À planifier **en dehors de ce dépôt cours** : registry d’images, orchestrateur (ECS, K8s, etc.), secrets, budgets.

**Risque coût** : deux tâches 24/7 ≠ un seul gros JAR — **chiffrer** avant de valider.

---

## 8. Risques (à garder en tête)

| Risque | Mitigation |
|--------|------------|
| Duplication front | Lib partagée + génération client OpenAPI (option) |
| Deux binaires = double config (JWT, CORS) | `core` unique ; tests ; paires d’environnements recette |
| Migrations | Un seul « propriétaire » Flyway |
| Parcours empiétant (trajets en lecture publique) | Recenser les matchers **avant** de couper `SecurityConfig` en deux chaines |

---

## 9. Avantages attendus (pourquoi faire ça)

- **Clarté produit** : parcours voyageur vs pro distincts, marque dédiée.
- **Cœur unique** : pas de double vérité métier si le domaine reste dans `core` / un seul schéma.
- **Évolution** : Phase 1 suffit souvent longtemps ; Phases 2–4 **à la demande**, pas par défaut.

---

## 10. Suivi (cocher en équipe)

| Phase | Statut (à mettre à jour) | Date / notes |
|-------|-------------------------|--------------|
| 0 Cadrage | ☑ | 2026-04-28 — [CADRAGE-PHASE-0.md](CADRAGE-PHASE-0.md) · ligne README « [État des phases](../README.md#phases-modularisation) » cochée. |
| 1.0 Deux fronts + lib | **Clôturé (code)** · voir § 4.1 | 2026-04 — E2E Playwright : voyageur (`npm run e2e`) + Business (`npm run e2e:business`) ; script [`e2e:all`](../frontend/package.json) |
| 1.1 Auth / session | **OK (code)** — `POST /v1/auth/refresh` + cookie refresh **httpOnly** (API) ; même chaîne **`apiInterceptor`** + **`authInterceptor`** + **`hydrateFromRefresh()`** sur **voyageur** et **`mobili-business`**. Limitation locale : **4200 ≠ 4201** ⇒ pas de session partagée sans domaine commun (voir §4.1) — hors scope « double login localhost » jusqu’aux domaines *.mobili.ci. | Recette infra quand DNS prêt |
| 1.2 Déploiement front business | **Infra hors dépôt** — à faire en cours (CI/CD, hébergement) ; **ne bloque pas** la clôture des phases « code » 0–2. | À brancher par équipe |
| 2 Mono structuré / core Maven | **Clôturé** — **`mobili-core`** : `MobiliApiPaths` ; **`mobili-boot`** : `api.passenger` / `api.partner` / `api.admin` + `module.*` (domaine) ; une seule app Spring. | 2026-04 ~ |
| 3 Deux JARs | **N/A par défaut** — ne lancer Phase 3 que si le besoin équipe/SLO/coûts est validé (§6). | |
| 4 Double ECS + CI | **N/A par défaut** — suit la Phase 3 si un jour elle est retenue (§7). | |

---

## 11. Fichiers utiles (repères)

- Backend (`mobili-boot/`) : `api/passenger/{auth,user,trip,booking,ticket,payment,gare,inbox}`, `api/partner/*`, `api/admin/*` ; `module/**` (domaine) ; `infrastructure/security/SecurityConfig.java` ; (`mobili-core/`) `MobiliApiPaths.java`
- Front : `frontend/src/app/app.routes.ts`, `core/guard/*.ts`
- (Optionnel plus tard) Infra : compose, cloud, CI — **hors périmètre** du dépôt cours actuel

---

## Clôture (ce que « terminer » les phases veut dire ici)

- **Mobili voyageur + Mobili Business + backend monolithique modularisé (Phases 0, 1.0 et 2)** : considéré **terminé dans le dépôt** lorsque **`npm run verify`** est vert et que le comportement **4200 / 4201** est validé (`README`, [§ État des phases](../README.md#phases-modularisation)).
- **Encore hors dépôt (normal)** : **1.2** mise en ligne (S3, CloudFront, DNS), affinage **1.1** sur les **domaines** de prod.
- **Phases 3 et 4** : **pas** nécessaires pour considérer le produit « deux façades + une API » comme livré ; à rouvrir seulement si l’architecture **deux binaires** est validée métier/infrastructure.

---

*Ce document est le **guide** convenu (pas seulement une idée de chat) : toute grosse entorse (ordre des phases, nombre de binaires) devrait y être notée ici et dans [ROADMAP.md](../ROADMAP.md) pour rester cohérents.*
