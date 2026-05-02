# Cadrage — Phase 0 (Mobili / Mobili Business)

Document **décisionnel** issu de l’inventaire code (avril 2026). Voir [FEUILLE-DE-ROUTE-MODULARISATION.md](FEUILLE-DE-ROUTE-MODULARISATION.md) pour les phases suivantes.

---

## 1. Décision produit (périmètre des bundles)

| Proposition | Décision | Commentaire |
|-------------|----------|-------------|
| **Espace compagnie** (`/partenaire/*`) + inscription `partenaire/register` | **Mobili Business** | Cœur offre pro (lignes, gares, chauffeurs, résas clients) |
| **Espace gare** (`/gare/*`) | **Mobili Business** (segment « opérations ») | Rattaché à une compagnie — même *marque* que le portail pro |
| **Covoiturage** (`/covoiturage/*`) | **Hors** « only business web » *pour le bundle secondaire* : conducteur = profil proche *terrain* | Reste aujourd’hui dans l’**app unifiée** ; pour un 2ᵉ *site* « Business », on peut l’**exclure** du 1er découpe (réduction risque) ou l’y inclure — ici on **coche l’inclusion optionnelle** (cohérent `ROLE_CHAUFFEUR` + pool partenaire) |
| **Chauffeur** (`/chauffeur/*`) | **Même logique** que covoit : opération terrain, pas « grand public» | Cible *Mobili* (voyage) vs *Business* = surtout **voyageur + recherche** ; chauffeur/covoit = **3ᵉ bandeau** "Opérations" possible dans app Business |
| **Admin** (`/admin/*`) | **Hors** Mobili Business (marque) — **Outils internes** Mobili | Ne pas mélanger avec le portail partenaire (souvent hôte / auth renforcés) |
| **Hôtes cibles (recette prod)** | `app.*` (ou `www`) = voyageur ; `business.*` = partenaire + gare | À figer en DNS + CORS + cookies ; en local : `localhost:4200` + `localhost:4201` |

> **Verrou Phase 0** : le *premier* découpe de front sépare clairement **(A)** public + voyageur + résa + paiement **(B)** partenaire + gare. Covoit / chauffeur / admin restent des **décisions d’inclusion** par itération (table § 3 *bundle cible*).

---

## 2. Routes front — préfixe → garde (résumé) → bundle cible

Lecture : [app.routes.ts](../frontend/src/app/app.routes.ts). Les guards imposent le **comportement** ; les **rôles** réels viennent du JWT côté API.

| Préfixe (chemins) | Garde(s) | Bundle cible | Rôle back typique* |
|--------------------|----------|--------------|---------------------|
| `""`, `search-results` | — | **Mobili** (public) | — |
| `auth/*` (login, inscription, register, gare, covoit) | — sauf compte requis ailleurs | **Commun** (tous comptes) | Selon parcours |
| `my-account/*` | `authGuard` | **Mobili** (voyageur) | `USER` + autres autorisés sur inbox |
| `partenaire/*` (+ `register`) | `authGuard`, parfois `partnerOperationsGuard` | **Business** | `PARTNER` / `GARE` (selon) |
| `gare/*` | `authGuard`, `gareOperationsGuard` (partie) | **Business** | `GARE` |
| `covoiturage/*` | `covoiturageSoloGuard` | **Inclusion TBD** (cf. §1) | `CHAUFFEUR` |
| `chauffeur/*` | `chauffeurGuard` | **Inclusion TBD** | `CHAUFFEUR` |
| `admin/*` | `adminGuard` | **Admin** (hors *Business* marque) | `ADMIN` |
| `booking/*`, `payment/*` | `authGuard` | **Mobili** (voyage) | `USER` |

\* Typique côté [UserRole.java](../backend/src/main/java/com/mobili/backend/module/user/role/UserRole.java) — la vérité = **autorisations** sur chaque `GET/POST` dans `SecurityConfig`.

---

## 3. Préfixes API (référence — pas de renommage requis)

Regroupement indicatif (contrôleurs `@RequestMapping` + [SecurityConfig](../backend/src/main/java/com/mobili/backend/infrastructure/security/SecurityConfig.java)) :

| Préfixe `/v1/...` | Publicité / rôles (résumé) |
|--------------------|----------------------------|
| `/v1/trips` (GET souvent public ; POST/PUT/DELETE pro/gare) | Voyageur + pro + mixte |
| `/v1/bookings`, `/v1/tickets` | Surtout `USER` + pro/gare |
| `/v1/auth` | Public + `me` authentifié |
| `/v1/inbox` | Multi-rôles |
| `/v1/payments` | Voyageur + callback public |
| `/v1/partners`, `/v1/partenaire/*` | `PARTNER` / `GARE` / `ADMIN` |
| `/v1/partner-gare-com` | Pro / gare |
| `/v1/covoiturage/trips` | `CHAUFFEUR` |
| `/v1/trips/{id}/driver` | Chauffeur + pro |
| `/v1/trips/chauffeur` | `CHAUFFEUR` |
| `/v1/admin` | `ADMIN` |

Aucun changement d’URL n’est *exigé* par la Phase 0 : **documenter** suffit pour les phases 1–2.

---

## 4. Checklist Phase 0 (statut)

| Item | Statut |
|------|--------|
| Périmètre **Mobili Business** = partenaire + gare (covoit/chauffeur = option) | Fait (ce doc) |
| Préfixes routes listés | Fait (§2) |
| Préfixes API listés | Fait (§3) |
| Hôtes cibles (noms) | Décrit §1 (à figer en infra quand dispo) |
| Lien README suivi (optionnel) | À l’équipe |

**Date de gel** : 2026-04-28 (mise à jour manuelle possible).

---

## 5. Suite logique

- **Phase 1** : 2e build front + lib partagée (voir [FEUILLE-DE-ROUTE](FEUILLE-DE-ROUTE-MODULARISATION.md#4-phase-1--produit--deux-facades-front-sans-toucher-le-jar-dabord)), CORS `4201` en dev.
- Ne pas lancer la Phase 3 (2 JARs) sans besoin d’exploitation documenté.
