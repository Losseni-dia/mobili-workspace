# Rapport factuel exhaustif — Application Mobili Pro (Flutter + Backend Spring Boot)

> Document de base factuelle destiné à la rédaction d'un plan de test QA (150+ scénarios).
> Sources : `mobilipro/` (app Flutter "Pro" — gares/partenaires/chauffeurs/admin), `mobile_app/` (app Flutter grand public — passagers + conducteurs covoiturage particuliers, cité en complément pour les flux qui n'existent que là), `backend/mobili-boot/` (API Spring Boot), `frontend/` (back-office Angular, cité ponctuellement).
> Tous les endpoints backend sont préfixés par `/v1` (`context-path: /v1`, `application.yml:7`).

---

## Constat structurel préliminaire

Le dépôt contient **deux applications Flutter distinctes** :
- **`mobilipro`** : app "Pro" utilisée par GARE, PARTNER (dirigeant compagnie), CHAUFFEUR (salarié compagnie) et ADMIN.
- **`mobile_app`** : app grand public utilisée par les passagers (USER) et les conducteurs de covoiturage **particuliers** (candidature KYC, dashboard conducteur, acceptation/refus de demandes).

Ce rapport couvre en priorité `mobilipro` (objet de la demande), et documente `mobile_app` pour les flux mentionnés dans la demande (KYC covoiturage, annulation de réservation) qui n'existent que côté grand public.

---

## 1. Rôles et accès

### 1.1 Rôles canoniques (backend, source de vérité)

Enum Java `module/user/role/UserRole.java` :
```java
public enum UserRole { USER, PARTNER, GARE, CHAUFFEUR, ADMIN }
```
- **USER** : client/passager (app grand public).
- **PARTNER** : dirigeant d'une compagnie de transport.
- **GARE** : responsable/équipe d'une gare rattachée à un partenaire.
- **CHAUFFEUR** : chauffeur salarié d'une compagnie (ou, via le flag métier séparé ci-dessous, conducteur particulier covoiturage).
- **ADMIN** : super-administrateur, accès total au dashboard admin.

Autorités Spring Security : préfixe `ROLE_` (`ROLE_USER`, `ROLE_PARTNER`, `ROLE_GARE`, `ROLE_CHAUFFEUR`, `ROLE_ADMIN`).

Un utilisateur peut cumuler **plusieurs rôles** (`profile.roles` est une `List<String>`, pas un rôle unique).

**Incohérence de convention relevée** : certains `@PreAuthorize` (ex. `UserReadController`) mélangent les formats `ROLE_x` et `x` bruts (`'ROLE_USER','USER',...`) dans la même expression — dette technique à signaler, potentiel symptôme de bug de contrôle d'accès si les autorités réelles n'ont jamais le format sans préfixe.

### 1.2 Sous-statut métier : covoiturage particulier

Pas un rôle Spring Security mais un flag sur le profil :
- `covoiturageSoloProfile: bool?` — vrai si conducteur particulier (distinct du chauffeur salarié).
- `covoiturageKycStatus` : `NONE | PENDING | APPROVED | REJECTED | EXPIRED` (enum backend `CovoiturageKycStatus.java`).
- Règle dérivée codée en dur : `isCovoiturageDriver = covoiturageSoloProfile == true && covoiturageKycStatus == 'APPROVED'` — **seule condition** autorisant la création/modification d'un trajet covoiturage.

**Anomalie relevée** : `ProfilePage` (`profile_page.dart:327-343`) teste aussi une chaîne `'COVOITURAGE'` dans `profile.roles` (badge "CONDUCTEUR") — ce mot n'existe dans aucun enum backend ; code mort probable, badge qui ne s'affichera jamais avec les rôles réels.

### 1.3 Accès par rôle — synthèse (mobilipro)

| Rôle | Shell (bottom nav) | Pages accessibles |
|---|---|---|
| **GARE** | ShellGare (6 onglets) | Dashboard gare, Trajets, Réservations, Chauffeurs, Notifications, Profil |
| **CHAUFFEUR** | ShellChauffeur (3 onglets) | Trajets (dashboard), Scanner QR, Profil |
| **PARTNER** | ShellPartner (5 onglets) | Dashboard, Gestion (gares/chauffeurs/chefs de gare), Communications (canal société + support), Notifications, Profil |
| **ADMIN** | ShellAdmin (6 onglets) | Dashboard (stats globales), Gestion (partenaires/utilisateurs/covoiturage), Logs d'activité, Communications (admin-com), Notifications, Profil |

### 1.4 Protection backend par rôle (extraits `SecurityConfig.java` / `@PreAuthorize`)

- `GareUserController` : classe entière `ROLE_PARTNER` seul.
- `PartenerReadController`, `PartnerChauffeurController`, `PartnerGareComController` : `PARTNER, GARE, ADMIN`.
- `StationController` : classe `PARTNER, GARE, ADMIN`, mais 5 méthodes d'écriture restreintes à `ROLE_PARTNER` seul.
- `TripWriteController` : `PARTNER, GARE, ADMIN`.
- `BookingController` : mix — création `ROLE_USER`, lecture pro `PARTNER/GARE/ADMIN`, ownership `#userId == principal.user.id`, une méthode `ROLE_ADMIN` seule.
- `TicketController` : mix `USER/PARTNER/ADMIN`, `CHAUFFEUR/GARE/ADMIN`, ownership.
- `ChauffeurTripController`, `CovoiturageProfileController`, `CovoiturageSoloTripController` : `CHAUFFEUR, ADMIN` (avec exception `isAuthenticated()` sur la candidature KYC — un simple USER doit pouvoir postuler).
- `TripDriverController` : `CHAUFFEUR, PARTNER, GARE, ADMIN`.
- `UserWriteController` : update global `ROLE_ADMIN`, update profil ownership `ADMIN or #id == principal.user.id`.
- Préfixe `/admin/**` : `ROLE_ADMIN` uniquement.
- Endpoints publics (`permitAll`) : `/error`, `/`, `/actuator/health`, `/actuator/prometheus`, `OPTIONS`, `/uploads/**`, `POST /auth/login|register|register-company|register-carpool-chauffeur|refresh|logout`, `GET /trips` et `/trips/**` (catalogue public), webhook paiement.

### 1.5 Point de sécurité côté client à tester

Le `redirect` de `go_router.dart` ne revérifie le rôle requis **qu'au moment où l'utilisateur est sur `/login`** (redirection initiale). Une fois connecté, **rien n'empêche par construction de naviguer par URL directe/deep-link vers l'espace d'un autre rôle** (ex. `context.go('/admin/dashboard')` depuis un compte GARE) — l'UI ne bloque pas, seul le backend protégerait les données réellement affichées. À tester explicitement.

---

## 2. Arborescence des écrans (routes)

Fichier source : `mobilipro/lib/core/router/go_router.dart`. Config : `initialLocation: '/login'`, aucune route `name:` déclarée (navigation par chemin littéral `context.go/push`), aucun `errorBuilder` (pas de page 404 dédiée).

### 2.1 Logique de redirection globale (guard)

```
- non connecté + route hors /login|/register* → redirige vers /login
- connecté + sur /login → redirige selon le PREMIER rôle qui matche, dans cet ordre strict :
    1. isChauffeur → /chauffeur/trips
    2. isAdmin     → /admin/dashboard
    3. isGare      → /gare/dashboard
    4. isPartner   → /partner/dashboard
    5. (aucun rôle) → /gare/dashboard (fallback par défaut, surprenant)
```
**Cas de test à couvrir explicitement** : utilisateur cumulant CHAUFFEUR + ADMIN → atterrit sur `/chauffeur/trips` (pas `/admin/dashboard`), car `isChauffeur` est testé en premier.

### 2.2 Tableau complet des routes

| Path | Widget | Fichier | Navigation | Rôle (déduit) |
|---|---|---|---|---|
| `/login` | `LoginPage` | `features/auth/presentation/pages/login_page.dart` | hors shell | public |
| `/register` | `RegisterChoicePage` | `features/auth/...` | hors shell | public |
| `/register/company` | `RegisterCompanyPage` | idem | hors shell | public |
| `/register/covoiturage` | `RegisterCarpoolChauffeurPage` | idem | hors shell | public |
| `/covoiturage/trips/new` | `CovoiturageTripFormPage` | `features/covoiturage/...` | plein écran | conducteur covoiturage approuvé |
| `/covoiturage/trips/:tripId/edit` | `CovoiturageTripFormPage(tripId)` | idem | plein écran | idem |
| `/gare/dashboard` | `DashboardGarePage` | `features/dashboard/...` | ShellGare branche 0 | GARE |
| `/gare/trips` | `TripsGarePage` | `features/trips/...` | ShellGare branche 1 | GARE |
| `/gare/trips/create` | `CreateTripPage` | `features/trips/...` | sous-page | GARE |
| `/gare/trips/canal/:tripId` | `CanalTripPage` | `features/canal/...` | sous-page | GARE |
| `/gare/bookings` | `BookingsGarePage` | `features/bookings/...` | ShellGare branche 2 | GARE |
| `/gare/chauffeurs` | `ChauffeursGarePage` | `features/chauffeurs/...` | ShellGare branche 3 | GARE |
| `/gare/notifications` | `NotificationsProPage` | `features/notifications/...` | ShellGare branche 4 | GARE |
| `/gare/profile` | `ProfilePage` | `features/auth/...` | ShellGare branche 5 | GARE |
| `/chauffeur/trips` | `DashboardChauffeurPage` | `features/dashboard/...` | ShellChauffeur branche 0 | CHAUFFEUR |
| `/chauffeur/scanner` (+`tripId`) | `ScannerPage` | `features/scanner/...` | ShellChauffeur branche 1 | CHAUFFEUR |
| `/chauffeur/profile` | `ProfilePage` | idem | ShellChauffeur branche 2 | CHAUFFEUR |
| `/partner/dashboard` | `DashboardPartnerPage` | `features/dashboard/...` | ShellPartner branche 0 | PARTNER |
| `/partner/dashboard/trips/create` | `CreateTripPage` | `features/trips/...` | sous-page | PARTNER |
| `/partner/gestion` | `PartnerGareManagersPage` | `features/stations/...` | ShellPartner branche 1 | PARTNER |
| `/partner/canal` | `PartnerGareComPage` | `features/partnergarecom/...` | ShellPartner branche 2 | PARTNER |
| `/partner/notifications` | `NotificationsProPage` | idem | ShellPartner branche 3 | PARTNER |
| `/partner/profile` | `ProfilePage` | idem | ShellPartner branche 4 | PARTNER |
| `/admin/dashboard` | `AdminDashboardPage` | `features/dashboard/...dashboard_admin_page.dart` | ShellAdmin branche 0 | ADMIN |
| `/admin/gestion` | `AdminGestionPage` | `features/admin/...` | ShellAdmin branche 1 | ADMIN |
| `/admin/logs` | `AdminActivityLogsPage` | `features/admin/...` | ShellAdmin branche 2 | ADMIN |
| `/admin/communications` | `AdminComPage` | `features/admincom/...` | ShellAdmin branche 3 | ADMIN |
| `/admin/notifications` | `NotificationsProPage` | idem | ShellAdmin branche 4 | ADMIN |
| `/admin/profile` | `ProfilePage` | idem | ShellAdmin branche 5 | ADMIN |

Notes :
- `ProfilePage` est le **même widget** réutilisé dans les 4 shells (contenu adapté dynamiquement).
- `NotificationsProPage` réutilisée dans GARE/PARTNER/ADMIN, **absente** du shell CHAUFFEUR (3 onglets seulement).
- `CreateTripPage` utilisée à deux endroits de l'arbre (gare et partenaire).
- Le détail trajet+passagers chauffeur (`TripDetailChauffeurPage`) est accessible via `Navigator.push` impératif depuis le dashboard chauffeur, **hors du routeur déclaratif** (pas dans ce tableau).
- Deux fichiers définissent une classe `AdminGestionPage`-like : `admin_gestion_page.dart` (routée, réelle) et `admin_gestion_page_v2.dart` (non routée, mais fournit les modèles/providers/`PartnerDetailPage`/`UserDetailPage` réellement utilisés par import `show`). Ne pas confondre en test.

### 2.3 Bottom navigation par rôle (détail)

**ShellAdmin** (6 items) : Dashboard / Gestion / Activité / Communications / Notifications (badge non-lu, `onTap` → `markAllRead()` auto) / Profil.

**ShellChauffeur** (3 items, pas de badge) : Trajets / Scanner / Profil.

**ShellGare** (6 items) : Dashboard / Trajets / Réservations / Chauffeurs / Notifications (badge, mark-all-read auto au tap) / Profil.

**ShellPartner** (5 items) : Dashboard / Gestion / Communications / Notifications (badge) / Profil.

**Bug relevé** : dans `shell_partner.dart`, le commentaire `// Index 4 = Notifications` est copié-collé depuis `ShellGare` mais **index 4 = Profil** dans ShellPartner (Notifications = index 3). Le code `if (i == 4) markAllRead()` se déclenche donc sur l'onglet **Profil** au lieu de Notifications → bug fonctionnel réel à tester (cliquer sur "Profil" côté Partner peut marquer les notifs comme lues par erreur ; cliquer sur "Notifications" — index 3 — ne le fait pas).

Aucun `Drawer` trouvé dans l'app — navigation exclusivement par bottom nav.

---

## 3. Détail des écrans (objectif, formulaires, actions, messages, API, états)

### 3.1 Authentification — `features/auth/`

**`LoginPage`** (`login_page.dart`)
- Champs : *"Identifiant ou email"* (obligatoire, message **"Identifiant requis"**, aucune regex email) ; *"Mot de passe"* (obscur togglable, obligatoire, **"Mot de passe requis"**).
- Bouton **"Se connecter"** (désactivé pendant chargement) ; lien **"Pas encore inscrit ? Créer un compte"** → `/register`.
- Endpoint : `POST /auth/login` `{login, password}` → puis `GET /auth/me`.
- Messages d'erreur exacts (`mobili_error.dart`) : `AUTH-001` *"Identifiant ou mot de passe incorrect."* ; `AUTH-002` *"Vous n'avez pas les droits nécessaires."* ; `MOB-001` *"Une erreur serveur est survenue. Veuillez réessayer."* ; `MOB-003` *"Certaines données saisies sont invalides."* ; `RATE_LIMITED` (429) *"Trop de requêtes — réessayez dans une minute."* ; `NETWORK_TIMEOUT` *"La connexion a expiré. Vérifiez votre réseau."*
- États : bandeau rouge d'erreur si `authState.errorMessage != null` ; bouton désactivé + spinner en chargement.

**Inscription compagnie** (`RegisterCompanyPage`, `/register/company`) : Prénom/Nom responsable, Email responsable, Identifiant, Mot de passe (**"6 caractères minimum"**), Nom compagnie, Email officiel, Téléphone, N° RCCM (optionnel), Logo (optionnel). `POST /auth/register-company` → connexion auto → `/partner/dashboard`.

**Inscription conducteur covoiturage** (`RegisterCarpoolChauffeurPage`, `/register/covoiturage`) : Téléphone, Marque véhicule, Plaque, Couleur, N° carte grise, Date validité CNI (demain à +15 ans), 4 photos obligatoires (CNI recto/verso, photo conducteur, photo véhicule). Messages exacts : **"La date de validité de la CNI est requise."**, **"Les 4 photos sont obligatoires (CNI recto/verso, vous, véhicule)."** `POST /auth/register-carpool-chauffeur` → compte créé **désactivé**, KYC `PENDING`, **pas** de connexion automatique.

**`ProfilePage`** (identique dans les 4 shells) : avatar, nom, badge de rôle coloré, sections *"Informations du compte"* (Nom, Identifiant `@login`, Email, Téléphone), *"Rôles & accès"* (chips rôles bruts), *"Statut"* (Actif/Désactivé). Bouton **"Se déconnecter"** → dialog **"Se déconnecter ?"** / *"Voulez-vous vraiment vous déconnecter de MobiliPro ?"*.

**`EditProfileProPage`** : Prénom, Nom, Email, Téléphone, Mot de passe (optionnel), Avatar (image picker 512×512, qualité 85). `PUT /users/{id}` multipart. Succès : **"Profil mis à jour ✓"**. Erreur : **`'Erreur : $e'`** — message brut **non localisé** (incohérence avec le reste de l'app).

**Gestion du token** : `flutter_secure_storage` (`EncryptedSharedPreferences` Android), clé `mobili_access_token`. Refresh via cookie httpOnly `MOBILI_REFRESH` (`PersistCookieJar`). Intercepteur 401 → `POST /auth/refresh` (garde anti-boucle) ; échec → purge storage+cookies → déconnexion implicite. JWT access 24h, refresh 7 jours (backend `JwtService.java`).

### 3.2 Dashboards — `features/dashboard/`

**`AdminDashboardPage`** : icônes loupe (→ `AdminSearchPage`) et refresh (invalide 4 providers). États `loading`/`error` (`'$e'`)/`data` par section.
- *Vue globale* : `GET /admin/stats` → KPI Utilisateurs, Partenaires, Trajets, Réservations, carte "Revenus totaux" (FCFA).
- *Inscriptions* : `GET /admin/stats/registrations?days=30`, KPI "Aujourd'hui"/"Total" + mini-graphe 7j. Détail (`RegistrationStatsDetailPage`) : période **7/30/90 jours**, tableau "Date"/"Inscriptions".
- *Connexions* : `GET /admin/stats/daily-logins?days=7`, KPI "Aujourd'hui"/"Uniques". Détail : 7/30/90 jours, tableau "Date"/"Total"/"Uniques" (30 lignes).
- *Statistiques trajets* : `GET /admin/stats/trip-analytics?period=WEEK`, libellé "7 derniers jours", KPI Réservations/Trajets actifs/Revenus/Moy. par résa + top 5 trajets. Détail : filtres **Aujourd'hui(DAY)/7 jours(WEEK)/1 mois(MONTH)**, top 5 par revenus et par réservations.

**`DashboardChauffeurPage`** : `GET /trips/chauffeur/mine`. FAB **"Publier un trajet"** (visible seulement si `isCovoiturageDriver`) → `/covoiturage/trips/new`. Header "Bonjour, {prénom}" + icône scanner. États erreur avec bouton **"Réessayer"**. Sections : "Prochain trajet" (vide → **"Aucun trajet à venir"**), "Aujourd'hui & demain" (vide → **"Aucun trajet aujourd'hui ou demain"**), "Mon activité covoiturage" (si covoiturage driver, `GET /covoiturage/trips/dashboard/stats`, vide → **"Aucune réservation pour le moment"**), "Historique" (vide → **"Aucun trajet passé"**). Badges statut : EN_COURS(vert)/PLANIFIE(bleu)/TERMINÉ(gris)/ANNULÉ(rouge).

**`DashboardGarePage`** : `GET /partenaire/dashboard/stats`. FAB **"Nouveau trajet"** → `/gare/trips/create`. KPI Trajets actifs/Réservations + Revenus (Via Mobili / Au guichet). "Réservations récentes" (10 max, vide → **"Aucune réservation récente"**).

**`DashboardPartnerPage`** : mêmes stats + `GET /partenaire/stations` pour "Mes gares" (vide → **"Aucune gare"**), badge "Dirigeant". Chaque gare cliquable → `GareDetailPage`.

**`GareDetailPage`** : filtres trajets **Tous/Programmés/En cours/Passés**, accordéon par trajet avec liste de réservations (siège, statut). Section "Chauffeurs affectés".

### 3.3 Gestion admin — `features/admin/`

**`AdminActivityLogsPage`** : `GET /admin/analytics/recent-events?limit=` (50, +50 par clic). Recherche texte locale, filtre type (dropdown : Tous/Connexion échouée/Réservation créée/Paiement confirmé/Trajet publié/Recherche sans résultat/Erreur serveur). Vide → **"Aucun événement trouvé"**.

**`AdminGestionPage`** — 3 onglets :
- *Partenaires* : `GET /admin/partners`, filtres Approbation (Toutes/En attente/Approuvés/Rejetés) + Statut (Tous/Actifs/Inactifs), recherche, pagination 20, export CSV. Actions : **"Approuver"** (`PATCH /admin/partners/{id}/approve`, succès **"{nom} approuvé ✅"**), **"Rejeter"** (dialog confirmation → `PATCH .../reject`, **"{nom} rejeté"**), **"Activer"/"Désactiver"** (`PATCH .../toggle`).
- *Utilisateurs* : `GET /admin/users`, filtres Rôle/Statut/Compagnie, toggle actif via `PATCH /admin/users/{id}/status?enabled=`, export CSV.
- *Covoiturage* : `GET /admin/covoiturage-solo-drivers`, filtres Statut KYC + Compte, export CSV.
- **`PartnerDetailPage`** : `GET /partners/{id}`. **`UserDetailPage`** : `GET /auth/{id}`, section KYC covoiturage avec boutons **"Approuver"/"Rejeter"** → `PATCH /admin/users/{id}/covoiturage-kyc?status=`, succès **"Statut KYC mis à jour : {status}"**.
- **`AdminSearchPage`** (icône loupe dashboard) : recherche globale groupée par section (Partenaires/Utilisateurs/Chauffeurs covoiturage), surlignage jaune du texte trouvé.

### 3.4 Support / Communication — `features/admincom/` et `features/partnergarecom/`

**`AdminComPage`** (admin) : `GET /admin-com/threads`, 4 onglets (Tous/Partenaires/Covoiturage/Support). FAB **"Nouveau message"** → dialog avec Destinataire (obligatoire, **"Sélectionnez un destinataire"**), Sujet (max 300, obligatoire), Message (max 4000, obligatoire) — erreur groupée **"Sujet et message obligatoires"**. `POST /admin-com/threads`. Fil : `GET /admin-com/threads/{id}/messages`, bulles droite/gauche selon auteur, `POST /admin-com/threads/{id}/messages` (rollback texte si échec).

**`PartnerGareComPage`** (partenaire/gare) : 2 onglets *"Canal société"* (interne compagnie, `GET/POST /partner-gare-com/threads`, portée **"Toutes les gares"** ou **"Gares ciblées"** avec sélection obligatoire si ciblé) et *"Canal support"* (avec Mobili, `GET /admin-com/threads`, **pas de FAB** — initié côté admin uniquement).

### 3.5 Notifications — `features/notifications/`

`NotificationsProPage` : rafraîchissement auto (`Timer.periodic` 30s), pagination manuelle (bouton **"Voir plus"**), filtrage client (masque `GARE_STATION_NEW_BOOKING`/`PARTNER_NEW_BOOKING` pour un partenaire pur non-gare). Bouton **"Tout lire"** (si non-lues>0), menu **"Tout supprimer"** (dialog **"Tout supprimer ?"**). Carte `Dismissible` (swipe suppression), tap → bottom sheet avec bouton d'action contextuel selon type (**"Voir le fil de discussion"**, **"Voir le message"**, **"Voir les trajets"**). API : `GET /inbox/notifications`, `GET .../unread-count`, `PATCH .../{id}/read`, `PATCH .../read-all`, `DELETE .../{id}`, `DELETE /inbox/notifications`.

### 3.6 Canal trajet — `features/canal/`

`CanalTripPage` : chat trajet↔passagers. `GET/POST /trips/{tripId}/channel/messages`. Bandeau **"Messages visibles par tous les passagers de ce trajet"**. Bulles droite (GARE/PARTNER/ADMIN/CHAUFFEUR) / gauche (passager). Vide → **"Aucun message"** / **"Envoyez un message aux passagers"**.

### 3.7 Trajets (transport public) — `features/trips/`

**`TripsGarePage`** : `GET /trips/my-trips`. Filtres Tous/Programmé/En cours/Terminé/Annulé. Actions par carte : Passagers, Canal, Vente (guichet), Modifier, masquer (**purement local, non persisté** — `Set<int>` en mémoire).

**`CreateTripPage`** — wizard 5 étapes :
1. *Trajet* : Ville départ*, Ville arrivée*, Point d'embarquement*, Date/heure* (aujourd'hui à +365j) — **"Obligatoire"** / **"Sélectionnez la date et l'heure de départ"**.
2. *Véhicule* : Type* (12 valeurs : BUS_CLIMATISE, BUS_CLASSIQUE, CAR_70_PLACES, MINIBUS, MASSA_NORMAL, MASSA_6_ROUES, VAN, SUV, BERLINE, CITADINE, MONOSPACE, PICKUP), Plaque, Nombre de places* (**"Nombre invalide"** si non numérique), photo optionnelle.
3. *Bagages* : switch + compteurs (cabine/soute inclus, max extra, prix extra) — aucune validation stricte.
4. *Prix & tronçons* : Prix complet* (**"Prix invalide"**), villes desservies (dynamique), prix par tronçon optionnel (calcul O(n²) des combinaisons).
5. *Chauffeur* : optionnel, `GET /partenaire/chauffeurs`, "Sans chauffeur assigné" par défaut.
- Soumission : `POST /trips` (multipart). Succès **"Trajet créé avec succès ! ✅"**. Erreur : message après "—" sinon **"Erreur lors de la création du trajet"**.

**`EditTripPage`** : mono-page, mêmes champs + `GET /trips/{id}` pour recharger tarifs de tronçons. `PUT /trips/{id}`. Succès **"Trajet modifié ✅"**. ⚠️ `partnerId` envoyé figé à `0` (pas relu du profil, contrairement à la création).

**Suppression** : aucune suppression de trajet "pro" classique (uniquement côté covoiturage, `DELETE /covoiturage/trips/{id}`).

**`OfflineSaleSheet`** (vente guichet) : sélecteurs Embarquement/Débarquement, plan de bus interactif (sièges occupés en rouge), nom passager obligatoire par siège. `POST /bookings/partner/offline-sale`. Erreur : **"Sélectionnez au moins une place"**, **"Le débarquement doit être après l'embarquement"**.

### 3.8 Réservations — `features/bookings/`

**`BookingsGarePage`** : **écran 100% lecture seule** — aucune action de confirmation/annulation/remboursement. `GET /trips/my-trips` + `GET /bookings/partner/my-bookings`. Filtres Tous/Via Mobili/En attente/Annulé/Au guichet.

**⚠️ Finding QA majeur** : côté `mobile_app` (passager), le bouton **"Annuler la réservation"** (`my_bookings_page.dart:927-963`) n'appelle **aucune API** — il affiche juste **"Annulation bientôt disponible"**. Aucun endpoint de remboursement n'est appelé nulle part dans les deux apps. La fonctionnalité "annulation/remboursement" demandée dans le brief **n'est pas implémentée** côté client.

### 3.9 Covoiturage — `features/covoiturage/` (mobilipro) + `mobile_app`

**`CovoiturageTripFormPage`** (seul écran covoiturage de mobilipro) : réservé aux `isCovoiturageDriver`. Types véhicule restreints (SUV/BERLINE/CITADINE/MONOSPACE/PICKUP). Champs : villes, point de RDV, date (+90j max), prix/place*, places proposées*. `POST/PUT /covoiturage/trips[/{id}]`. Succès **"Trajet publié ✅"** / **"Trajet modifié ✅"**.

**Candidature KYC** (`mobile_app`) : `CovoiturageRegisterPage` (non connecté, `POST /auth/register-carpool-chauffeur`) ou `CovoiturageApplyPage` (connecté, `POST /covoiturage/profile/apply`). Mêmes 4 photos + date CNI obligatoires.

**⚠️ Finding QA majeur — gap fonctionnel KYC** : l'endpoint `PATCH /admin/users/{id}/covoiturage-kyc` existe côté backend et **est bien utilisé** par `UserDetailPage` (mobilipro, boutons Approuver/Rejeter, voir §3.3) — donc le traitement KYC **existe** côté mobilipro via la fiche détail utilisateur. En revanche, côté front Angular (`admin-partners.ts`), la page équivalente n'expose **aucun bouton Approuver/Rejeter** (seulement affichage du statut + bascule Actif/Inactif) : le traitement KYC n'est possible que depuis l'app mobile admin, pas depuis le back-office web — point à vérifier/tester.

**Dashboard conducteur + demandes en attente** (`mobile_app`, onglet absent côté mobilipro) : `CovoiturageTripDetailPage`, onglet *Demandes* → `GET /covoiturage/trips/{tripId}/pending-requests`. Boutons **"Accepter"** (`POST .../bookings/{bookingId}/accept`, succès **"Demande acceptée ✅"**) / **"Refuser"** (`POST .../reject`, succès **"Demande refusée"**), désactivés pendant l'action (anti double-clic). Délais métier : **24h** pour la réponse du chauffeur, **30 min** pour le paiement après acceptation (`CovoiturageBookingExpiryScheduler`, cadence toutes les **5 minutes**).

### 3.10 Chauffeurs (compagnie) — `features/chauffeurs/`

**`ChauffeursGarePage`** : `GET /partenaire/chauffeurs`. Filtres Actifs/Archivés/Tous. FAB **"Nouveau chauffeur"**.
- Formulaire (`_ChauffeurFormSheet`) : Prénom*, Nom*, Identifiant/login* (création seule), Téléphone*, Email (optionnel, sans validation format ici), Mot de passe* (création, **"Min 8 caractères"** ; optionnel en édition). `POST/PUT /partenaire/chauffeurs[/{id}]`. Succès **"Chauffeur créé avec succès ! ✅"** / **"Chauffeur modifié avec succès ! ✅"**.
- **"Désinscrire"** (dialog confirmation) → `DELETE /partenaire/chauffeurs/{id}` (désactivation logique, pas suppression) → **"{nom} archivé — visible dans 'Archivés'"**. **"Réintégrer"** → `PATCH .../reactivate` → **"{nom} réintégré avec succès ! ✅"**.
- Affectation à un trajet : se fait depuis `CreateTripPage`/`EditTripPage` (champ `assignedChauffeurId`), pas depuis cet écran.

**`TripDetailChauffeurPage`** : bouton **"Démarrer"** (`POST /trips/{id}/driver/start`, succès **"Trajet démarré ✅"**). Modifier/Supprimer visibles **uniquement** pour trajets covoiturage. 3 onglets : Passagers, Arrêts (montées/descentes, **"Terminer le trajet"**), Scanner.

### 3.11 Gares/Stations — `features/stations/`

**`PartnerGareManagersPage`** ("Gestion", 3 onglets) :
- *Gares* : `GET /partenaire/stations`. Badge En attente(orange)/Active(vert)/Inactive(rouge). Formulaire (Nom*, Ville*) → `POST/PUT /partenaire/stations[/{id}]`. **"Approuver"** (bandeau tappable si en attente) → `POST .../{id}/approve` → **"{nom} approuvée et activée !"**. Toggle actif → `PUT` avec `active`.
- *Chauffeurs* : mêmes règles que §3.10 + affiliation à une gare (`PATCH /partenaire/chauffeurs/{id}/affiliation`, `{stationId}` ou `null` pour retirer).
- *Chefs de gare* : `GET /partenaire/gare-users`. Formulaire (Prénom*, Nom*, Téléphone* **"Min 8 caractères"**, Email optionnel **"Email invalide"** si mal formé, Login* création seule, Mot de passe* **"Min 6 caractères"**, Gare d'affectation* création seule). `POST /partenaire/stations/gare-accounts` / `PUT /partenaire/gare-users/{id}`. Réaffectation : `PATCH .../affiliation`.
- **Remarque transverse** : la plupart des erreurs de ces 3 onglets affichent `'Erreur : $e'` brut (exception technique), **sans** passer par le mapping localisé `MobiliException` — à tester en déclenchant volontairement des doublons/erreurs.

### 3.12 Scanner QR — `features/scanner/` + `shared/widgets/qr_scanner_widget.dart`

Voir détail complet en section 4.3 (flux métier).

---

## 4. Flux métier complexes (step-by-step)

### 4.1 Création / modification / suppression d'un trajet (transport public)

1. **Création** : `CreateTripPage`, wizard 5 étapes (voir §3.7) → `POST /trips` (multipart, champ `trip` JSON + `vehicleImage`). Le body inclut `partnerId` (du profil connecté), `transportType: 'PUBLIC'`, `availableSeats = totalSeats`, `legFares` (tarifs par tronçon).
2. **Modification** : `EditTripPage` pré-rempli + recharge `legFares` via `GET /trips/{id}` → `PUT /trips/{id}`. `availableSeats` repris tel quel (jamais recalculé côté client). `partnerId` envoyé à `0` (figé, à vérifier côté backend).
3. **Suppression** : **non implémentée** pour les trajets "pro" classiques (transport public) — uniquement pour les trajets covoiturage (`DELETE /covoiturage/trips/{id}`).
4. Règles métier backend (`TripService.assertTripWriteAccess`) : le trajet doit appartenir au partenaire courant ; si compte GARE, doit appartenir à sa gare. Prix négatif refusé. Si >2 arrêts, `originDestinationPrice` obligatoire et positif.

### 4.2 Réservations : confirmation, annulation, remboursement

1. **Création** (passager, `mobile_app`) : `POST /bookings`. Si trajet covoiturage → statut `PENDING_DRIVER_APPROVAL` (délai réponse chauffeur 24h) ; sinon → `PENDING`.
2. **Confirmation via paiement wallet** : `BookingService.confirmPayment` — statut doit être `PENDING`/`AWAITING_PAYMENT`, vérifie solde (`PAY-001` si insuffisant), débite, passe `CONFIRMED`, génère tickets. Seul admin/partenaire propriétaire peut confirmer manuellement.
3. **Confirmation via FedaPay** : webhook `POST /payments/callback` (header `X-Webhook-Secret`) ou `POST /payments/verify/{bookingId}` (relecture statut).
4. **Annulation** : **non implémentée côté client** dans les deux apps (bouton "Annulation bientôt disponible" côté passager, absent côté gare/partenaire). Backend possède le concept (`BKG-001 BOOKING_ALREADY_CANCELLED`) mais aucune UI ne déclenche l'annulation.
5. **Remboursement** : **aucun endpoint ni UI trouvés** dans le code exploré.
6. **Vente au guichet** (gare/partenaire) : `POST /bookings/partner/offline-sale`, statut `OFFLINE_SALE`, sièges bloqués manuellement possibles via `POST /bookings/partner/deactivate-seats`.
7. **Contrôle d'accès** (`BookingService.enforceCanAccessBooking`) : ADMIN, client propriétaire, partenaire propriétaire du trajet, ou compte GARE dont la gare correspond au trajet.

### 4.3 Scanner QR (billet valide / invalide / déjà utilisé / hors ligne)

Widget central : `shared/widgets/qr_scanner_widget.dart` (`QrScannerWidget`), réutilisé à 4 endroits (route `/chauffeur/scanner`, dashboard chauffeur, détail trajet chauffeur, sheet passagers).

1. Caméra (`mobile_scanner`) tourne en continu ; `onDetect` se déclenche automatiquement (pas de bouton "scanner" explicite). Garde anti-double-scan (`_isProcessing`).
2. Détection → caméra stoppée → overlay chargement **"Vérification..."**.
3. Extraction du numéro de ticket (regex JSON ou contenu brut, **aucune validation de format** avant appel API).
4. **Avec `tripId`** (scan depuis un trajet = confirmation de montée) : `PATCH /tickets/verify/{ticketNumber}`. ⚠️ `valid: true` **codé en dur** dès que le HTTP répond 2xx, sans inspecter le champ `status` retourné.
5. **Sans `tripId`** (vérification simple) : `GET /tickets/{ticketNumber}`, `valid = status IN ('CONFIRMED','USED')` — ⚠️ un ticket **déjà utilisé** (`USED`) est donc affiché comme **valide** (bandeau vert) dans ce mode.
6. **Cas valide** : overlay vert, **"Ticket Valide ✓"**, détails passager/siège/trajet/statut, bouton **"Scanner un autre ticket"**. Aucun son/vibration (pas de `HapticFeedback` dans le code).
7. **Cas invalide/erreur** : overlay rouge, **"Ticket Invalide ✗"**. ⚠️ **Finding majeur** : le `catch` générique affiche systématiquement **"Ticket invalide ou introuvable"**, quelle que soit la cause réelle — alors que le backend distingue `MOB-002` (introuvable), `BKG-002` (déjà utilisé — *"Ce ticket a déjà été utilisé."*), `BKG-003` (annulé), `BKG-004` (expiré), `TRP-002` (embarquement fermé), `NETWORK_TIMEOUT` (pas de réseau). **Aucun de ces messages n'atteint l'écran du scanner** — à tester en priorité (scanner un billet déjà utilisé doit normalement afficher un message distinct, ce qui n'est pas le cas actuellement).
8. **Hors ligne** : aucun cache local ni file d'attente de synchronisation pour le scanner (confirmé par absence de `connectivity_plus`/`Hive`/`sqflite` dans `pubspec.yaml`). Une coupure réseau produit le même message générique "Ticket invalide ou introuvable" qu'un vrai ticket invalide — trompeur pour le chauffeur.
9. **Permissions caméra** : Android déclarée (`AndroidManifest.xml`). ⚠️ iOS : **`NSCameraUsageDescription` absente** de `Info.plist` — risque de crash immédiat au premier accès caméra sur iOS, à vérifier en priorité sur build réel.
10. La descente ("arrivé") n'est pas scannée : elle est déduite automatiquement quand le chauffeur enregistre son départ de la ville de descente (`POST /trips/{id}/driver/departures`).

### 4.4 Gestion des chauffeurs (création, affectation, activation/désactivation)

1. **Création** : `_ChauffeurFormSheet` → `POST /partenaire/chauffeurs` (voir §3.10).
2. **Affectation à un trajet** : depuis `CreateTripPage` (étape 5) ou `EditTripPage`, champ `assignedChauffeurId`, liste `GET /partenaire/chauffeurs`. Règle backend : le chauffeur doit être employé du partenaire, et si le trajet est rattaché à une gare, affilié à cette même gare.
3. **Désactivation ("Désinscrire")** : `DELETE /partenaire/chauffeurs/{id}` (désactivation logique, jamais suppression physique).
4. **Réintégration** : `PATCH /partenaire/chauffeurs/{id}/reactivate`.
5. **Affiliation à une gare** : `PATCH /partenaire/chauffeurs/{id}/affiliation` (`{stationId}` ou retrait).
6. Contrôle d'accès (`PartnerChauffeurService`) : chaque opération vérifie que le chauffeur appartient à la compagnie de l'appelant — sinon `RESOURCE_NOT_FOUND` (masquage volontaire, pas `ACCESS_DENIED`, pour ne pas révéler l'existence d'un chauffeur d'une autre compagnie).

### 4.5 Gestion des gares/stations

1. **Création** : `POST /partenaire/stations` (Nom*, Ville*) → créée `PENDING`, `active=false`, code unique `GAR-XXXXX`.
2. **Approbation** : `POST /partenaire/stations/{id}/approve` — réservé au dirigeant (`requirePartnerOwner`), active tous les comptes rattachés à cette gare.
3. **Activation/désactivation** : `PUT /partenaire/stations/{id}` avec `active`.
4. **Suppression** : `DELETE /partenaire/stations/{id}` — **interdite** si des comptes gare y sont rattachés ou si des trajets la référencent encore.
5. Une gare doit être **validée ET active** pour publier des trajets (`assertStationOperationalForTripUse`).

### 4.6 Validation KYC covoiturage

1. Le candidat postule (`POST /auth/register-carpool-chauffeur` ou `POST /covoiturage/profile/apply`) → statut `PENDING`.
2. L'admin consulte la liste : `GET /admin/covoiturage-solo-drivers` (via `AdminGestionPage` onglet Covoiturage, mobilipro).
3. Traitement du dossier : depuis `UserDetailPage` (mobilipro), boutons **"Approuver"**/**"Rejeter"** → `PATCH /admin/users/{id}/covoiturage-kyc?status=APPROVED|REJECTED`. Si `APPROVED`, seul bouton "Rejeter" reste disponible ensuite (`showRejectOnly`).
4. Une fois `APPROVED`, le conducteur peut publier des trajets covoiturage (`isCovoiturageDriver == true`).
5. Expiration automatique : `CovoiturageKycExpiryJob.java` (backend) fait passer `APPROVED → EXPIRED` si la CNI expire — aucune UI ne déclenche ce job manuellement.
6. **Gap relevé** : le back-office Angular (`admin-partners.ts`) affiche le statut KYC mais **ne propose pas** de bouton Approuver/Rejeter (seulement bascule Actif/Inactif du compte) — le traitement n'est possible que depuis l'app mobile.

### 4.7 Support client (conversations, réponses, filtrage)

Deux systèmes distincts (voir §3.4) :
- **AdminCom** (admin ↔ partenaires/covoiturage/support) : `GET/POST /admin-com/threads`, filtrage par type (Tous/Partenaires/Covoiturage/Support), création par n'importe quel profil (routée automatiquement vers un admin si non-admin) ou ciblée par l'admin.
- **PartnerGareCom** (interne compagnie + support Mobili) : `GET/POST /partner-gare-com/threads`, portée ALL (dirigeant seul) ou TARGETED (gares spécifiques, ou sa propre gare seule si compte GARE). Titre unique par partenaire (`DUPLICATE_RESOURCE` si doublon).

### 4.8 Gestion des compagnies partenaires (admin)

1. Liste : `GET /admin/partners`, filtres Approbation/Statut, tri (en attente en premier), export CSV.
2. **Approuver** : `PATCH /admin/partners/{id}/approve`.
3. **Rejeter** : dialog confirmation → `PATCH /admin/partners/{id}/reject`.
4. **Activer/Désactiver** : `PATCH /admin/partners/{id}/toggle`.
5. Une compagnie non `enabled` ne peut pas opérer (`assertPartnerCanOperate`).
6. ⚠️ **Finding sécurité** : `PUT /partners/{id}` (modification profil compagnie) est protégé uniquement par `hasAnyAuthority('ROLE_PARTNER','ROLE_ADMIN')` **sans vérification que l'`id` du chemin correspond au partenaire authentifié** — contrairement aux autres services (Booking, Ticket, PartnerChauffeur) qui comparent explicitement l'identité. **IDOR potentiel à tester** : un partenaire A pourrait modifier la fiche (nom, email, téléphone, n° entreprise, logo) d'un partenaire B en appelant `PUT /v1/partners/{id_B}` avec son propre token.

### 4.9 Statistiques / analytics affichées

Voir détail complet §3.2 (Dashboard Admin). Récapitulatif des périodes disponibles :
- Inscriptions & connexions : 7 / 30 / 90 jours.
- Analytics trajets : DAY / WEEK / MONTH (période par défaut affichée en résumé : WEEK, libellé "7 derniers jours").
- Dashboard gare/partenaire : pas de sélecteur de période, stats globales "à date" + répartition Via Mobili / Au guichet.

### 4.10 Gestion des paiements (historique, détail, remboursement manuel)

- `POST /payments/checkout/{bookingId}` : crée une session FedaPay.
- `POST /payments/verify/{bookingId}` : relit le statut FedaPay et confirme la réservation si approuvé.
- `POST /payments/callback` (webhook, header `X-Webhook-Secret`) : confirme automatiquement si `status=approved`.
- **Aucun écran "historique des paiements" ni "remboursement manuel" trouvé côté mobilipro** — les paiements se déduisent uniquement des sections revenus des dashboards (Via Mobili / Au guichet) et de la liste des réservations. Aucun endpoint de remboursement identifié dans le backend exploré.

---

## 5. Backend — endpoints et règles métier

### 5.1 Liste des contrôleurs et endpoints principaux

*(préfixe commun `/v1` omis ci-dessous)*

| Contrôleur | Endpoints |
|---|---|
| `AdminController` (`/admin`) | `PATCH partners/{id}/approve|reject|toggle`, `GET users`, `GET partners`, `GET covoiturage-solo-drivers`, `PATCH users/{id}/status?enabled=`, `PATCH users/{id}/employer-partner?partnerId=`, `GET stats`, `GET stats/daily-logins?days=`, `GET analytics/summary?days=`, `GET analytics/recent-events?limit=`, `GET stats/trip-analytics?period=`, `GET stats/registrations?days=`, `PATCH users/{id}/covoiturage-kyc?status=` |
| `AdminPartnerCommunicationController` (`/admin`) | `POST partner-communications` |
| `AdminComController` (`/admin-com`) | `POST threads`, `GET threads`, `GET threads/{id}/messages`, `POST threads/{id}/messages` |
| `PartnerChauffeurController` (`/partenaire/chauffeurs`) | `GET`, `POST`, `PATCH {id}/affiliation`, `PUT {id}`, `PATCH {id}/reactivate`, `DELETE {id}` |
| `GareUserController` (`/partenaire/gare-users`) | `GET`, `PUT {id}`, `PATCH {id}/affiliation`, `PATCH {id}/reactivate`, `DELETE {id}` |
| `StationController` (`/partenaire/stations`) | `GET`, `POST`, `PUT {id}`, `POST {id}/approve`, `DELETE {id}`, `POST gare-accounts` |
| `PartenerReadController` (`/partners`) | `GET`, `GET {id}`, `GET my-company` |
| `PartnerWriteController` (`/partners`) | `POST` (multipart), `PUT {id}` (multipart), `PATCH {id}/toggle`, `DELETE {id}` |
| `PartnerGareComController` (`/partner-gare-com`) | `GET threads`, `POST threads`, `GET threads/{id}/messages`, `POST threads/{id}/messages` |
| `PartnerDashboardController` (`/partenaire/dashboard`) | `GET stats?stationId=` |
| `TripWriteController` (`/trips`) | `POST price-preview`, `POST` (multipart), `PUT {id}` (multipart), `DELETE {id}` |
| `BookingController` (`/bookings`) | `POST`, `PATCH {id}/confirm`, `GET user/{userId}`, `GET trips/{tripId}/occupied-seats`, `GET {id}`, `GET`, `GET partner/my-bookings`, `POST partner/deactivate-seats`, `GET trips/{tripId}/passengers`, `POST partner/offline-sale` |
| `AuthController` (`/auth`) | `POST login`, `POST refresh`, `POST logout`, `POST register` (multipart), `POST register-company` (multipart), `POST register-carpool-chauffeur` (multipart) |
| `GareAuthController` (`/auth/registration`) | `GET gare/preview?code=`, `POST gare` |
| `PaymentController` (`/payments`) | `POST checkout/{bookingId}`, `POST verify/{bookingId}`, `POST callback` |
| `TicketController` (`/tickets`) | `POST`, `GET user/{userId}`, `PATCH {id}/cancel`, `PATCH verify/{ticketNumber}`, `GET trip/{tripId}` |
| `UserWriteController` (`/users`) | `PATCH {id}/toggle-status?enabled=`, `PUT {id}` (multipart) |
| `UserReadController` (`/auth`) | `PATCH me/fcm-token`, `GET`, `GET {id}`, `GET me` |
| `TripReadController` (`/trips`) | `GET cities?q=`, `GET ?transportType=`, `GET {id}/stops`, `GET {id}`, `GET search?...`, `GET my-trips` |
| `CovoiturageSoloTripController` (`/covoiturage/trips`) | `GET pending-requests`, `GET {id}/pending-requests`, `POST {tripId}/bookings/{bookingId}/accept|reject`, `GET`/`GET mine`, `POST`, `PUT {id}`, `GET {id}/bookings`, `DELETE {id}`, `GET dashboard/stats` |
| `TripChannelController` (`/trips/{tripId}/channel`) | `GET messages`, `POST messages` |
| `TripDriverController` (`/trips/{tripId}/driver`) | `POST departures`, `POST departures/undo`, `POST start`, `GET luggage-summary`, `GET stops/{i}/alightings|boardings`, `POST tickets/{n}/alighted` |
| `TripRatingController` (`/trips`) | `POST {tripId}/ratings`, `GET {tripId}/ratings/mine|average` |
| `CovoiturageProfileController` (`/covoiturage/profile`) | `PUT`, `POST apply` |
| `ChauffeurTripController` (`/trips/chauffeur`) | `GET mine` |
| `InboxNotificationController` (`/inbox`) | `GET notifications`, `GET notifications/unread-count`, `PATCH notifications/{id}/read`, `PATCH notifications/read-all`, `DELETE notifications/{id}`, `DELETE notifications` |
| `InboxSseController` (`/inbox`) | `GET sse` (SSE temps réel) |
| `PrivateMediaController` (`/media`) | `GET private?rel=` |

### 5.2 Contraintes de validation Bean Validation (principales)

- `PartnerChauffeurCreateRequest` : `firstname/lastname` NotBlank+Size(100), `email` Size(255)+Email, `phone` NotBlank+Size(8-20), `login` NotBlank+Size(2-80), `password` NotBlank+Size(8-120).
- `StationRequestDTO` : `name`/`city` NotBlank (messages "Le nom de la gare est obligatoire" / "La ville est obligatoire").
- `GareUserCreateRequest` : `stationId` NotNull, `login` NotBlank+Size(2-64), `phone` NotBlank+Size(20), `password` NotBlank+Size(6-128).
- `TripRequestDTO` : `partnerId` NotNull, `departureCity/arrivalCity/boardingPoint` NotBlank, `vehiculePlateNumber` NotBlank, `vehicleType` NotNull, `departureDateTime` NotNull, `price` NotNull+Min(0), `totalSeats`/`availableSeats` NotNull+Min(1).
- `CovoiturageSoloTripRequestDTO` : mêmes champs trajet, `price` NotNull+Min(0), `totalSeats` NotNull+Min(1).
- `TripRatingRequest` : `note` NotNull+Min(1)+Max(5), `comment` Size(500).
- `RegisterDTO` : `firstname/lastname/login` NotBlank, `email` Email (pas NotBlank), `phone` NotBlank+Size(8-15), `password` NotBlank+Size(min=8).
- `RegisterCarpoolChauffeurDTO` : date fin validité pièce d'identité NotNull+**@Future**, marque/immatriculation/couleur/carte grise NotBlank+Size.
- `BookingRequestDTO` : `tripId` NotNull, `selections` NotEmpty, `numberOfSeats` NotNull+Min(1).
- `CreateAdminComThreadRequest` / `CreatePartnerGareComThreadRequestDTO` / `PostAdminComMessageRequest` / `PostPartnerGareComMessageRequestDTO` : sujet/titre NotBlank+Size(200-300), message/body NotBlank+Size(2000-4000).

### 5.3 Codes d'erreur personnalisés (`MobiliErrorCode.java`)

| Code | HTTP | Message |
|---|---|---|
| `MOB-001` | 500 | "Une erreur interne est survenue." (fallback générique) |
| `MOB-002` | 404 | "La ressource demandée n'existe pas." |
| `MOB-003` | 400 | "Données invalides." (aussi `@Valid` échoué) |
| `MOB-004` | 409 | "Cette ressource existe déjà." (aussi doublons DB) |
| `TRP-001` | 409 | "Plus de places disponibles pour ce trajet." |
| `TRP-002` | 409 | "Plus de réservation avec embarquement à cet arrêt (départ enregistré ou heure planifiée dépassée)." |
| `VHC-001` | 409 | "Ce véhicule est déjà assigné à un autre trajet sur cette période." |
| `BKG-001` | 400 | "Cette réservation est déjà annulée." |
| `BKG-002` | 409 | "Ce ticket a déjà été utilisé." |
| `BKG-003` | 409 | "Ce ticket a été annulé et ne peut plus être utilisé." |
| `BKG-004` | 409 | "Désolé, ce ticket a expiré" |
| `PAY-001` | 409 | "Solde insuffisant !" |
| `AUTH-001` | 401 | "Identifiants incorrects." |
| `AUTH-002` | 403 | "Vous n'avez pas les droits nécessaires." |
| `RATE_LIMITED` | 429 | "Trop de requêtes depuis cette adresse. Réessayez dans une minute." |

Attention : le préfixe `MOB-` sert aussi (sans rapport) de préfixe de génération d'identifiants métier (`Ticket.ticketNumber`, ex. `MOB-A1B2C3D4`) — ne pas confondre avec les codes d'erreur.

### 5.4 Règles métier clés dans les services

- **`BookingService`** : plafond bagages extra (`numberOfSeats × maxExtraHoldBagsPerPassenger`), délais covoiturage (24h réponse / 30min paiement), accès restreint (propriétaire/admin/gare correspondante), `findAll()` réservé ADMIN.
- **`PartnerService`** : compagnie doit être `enabled` pour opérer ; seul le dirigeant (sans `station`) peut effectuer certaines actions ; code d'inscription unique (20 tentatives max) ; création en `PENDING`/`enabled=false`.
- **`PartnerChauffeurService`** : masquage volontaire (`RESOURCE_NOT_FOUND` plutôt que `ACCESS_DENIED`) si le chauffeur ciblé n'appartient pas à la compagnie de l'appelant — ne révèle pas l'existence de chauffeurs d'autres compagnies.
- **`StationService`** : gare doit être validée + active pour publier des trajets ; suppression interdite si comptes/trajets rattachés ; unicité email/login vérifiée explicitement.
- **`TripService`/`TripRunService`** : `NO_SEATS_AVAILABLE` (TRP-001) si siège occupé sur le segment ; `BOARDING_CLOSED` (TRP-002) si arrêt déjà quitté ou heure dépassée ; affectation chauffeur limitée à un employé affilié à la bonne gare.

### 5.5 Scheduler d'expiration des réservations covoiturage

`CovoiturageBookingExpiryScheduler` — cadence **5 minutes**. Règle 1 : `PENDING_DRIVER_APPROVAL` + délai 24h dépassé → `EXPIRED` (sièges libérés, notification passager). Règle 2 : `AWAITING_PAYMENT` + délai 30min dépassé → `EXPIRED` (idem).

---

## 6. Cas limites déjà prévus (ou non) dans le code

### 6.1 Hors connexion

**Aucune gestion offline** dans mobilipro : pas de `connectivity_plus`, pas de cache local (`Hive`/`sqflite`/`Drift`/`Isar` absents), pas de file de synchronisation différée. Toute action nécessite le réseau. Le terme "offline" dans le code (`OfflineSaleSheet`, `BookingStatus.OFFLINE_SALE`) désigne uniquement la vente **au guichet en espèces**, pas un mode dégradé de l'app.

**Conséquence testée dans le code** : `AuthNotifier.build()` attrape indistinctement une session expirée et une erreur réseau — un utilisateur avec token valide mais sans réseau au lancement est redirigé vers `/login` comme s'il était déconnecté.

### 6.2 Timeouts / erreurs réseau

Configuration (`api_client.dart`, commentée *"tuned for slow African mobile networks"*) : `connectTimeout=15s`, `receiveTimeout=30s`, `sendTimeout=30s`. Timeouts → `NETWORK_TIMEOUT` → *"La connexion a expiré. Vérifiez votre réseau."* ⚠️ `DioExceptionType.connectionError` (pas de réseau/DNS) **n'est pas normalisé explicitement** comme les timeouts — remonte en `DioException` brute avec message générique *"Erreur réseau inconnue."* Pattern UI répété : message + bouton **"Réessayer"** (14+ écrans).

### 6.3 Session expirée / déconnexion forcée

- Intercepteur 401 → tentative refresh (`POST /auth/refresh`, garde anti-boucle) → échec → purge token+cookies → déconnexion implicite (redirection `/login` au prochain accès, pas d'appel `logout()` explicite dans ce cas).
- **403 non géré spécifiquement** côté client (seul 401 déclenche un refresh) — remonte comme erreur générique.
- ⚠️ **Le correctif "Android Keystore corrompu"** (commit `172bb49`, gérant `AEADBadTagException` avec retry/nettoyage automatique) **a été appliqué uniquement dans `mobile_app`**, **absent de `mobilipro`** — `saveToken`/`readToken`/`clearSession` n'ont pas de `try/catch`/recovery équivalent. À tester sur un appareil au Keystore corrompu.
- JWT : access 24h, refresh 7 jours (cookie httpOnly `MOBILI_REFRESH`, `sameSite=Lax`, `secure=true` en prod).

### 6.4 Contrôle d'accès entre partenaires

**Contrôles explicites présents** : `BookingService` (propriétaire/gare correspondante), `TicketService`, `PartnerChauffeurService` (masquage `RESOURCE_NOT_FOUND`), `StationService`, `TripService`.

⚠️ **Contrôle manquant identifié** : `PUT /partners/{id}` (`PartnerWriteController.update` + `PartnerService.save` branche mise à jour) — **aucune vérification que l'`id` du chemin correspond au partenaire authentifié**. La règle Spring Security n'autorise que par rôle (`ROLE_PARTNER`/`ROLE_ADMIN`), pas par identité de ressource. **Test IDOR à effectuer explicitement** : partenaire A appelant `PUT /v1/partners/{id_B}` avec son propre token.

### 6.5 Rate limiting

`MobiliAuthRateLimitFilter` — actif uniquement sur `/auth/**` et `POST /payments/callback`. Limites : login/refresh **25/min**, inscriptions **10/min**, preview gare **60/min**, webhook paiement **120/min**. Réponse 429 : `{"message":"Trop de requêtes depuis cette adresse. Réessayez dans une minute.","code":"RATE_LIMITED"}`. ⚠️ **Fail-open par défaut** (`allow-on-redis-failure: true`) : si Redis tombe, la limitation est désactivée sans alerte. ⚠️ IP résolue via `X-Forwarded-For` sans liste de proxies de confiance — potentiel contournement par falsification d'en-tête. **Aucune limitation sur les endpoints métier** (trajets, réservations, tickets, dashboard).

---

## Récapitulatif des findings QA majeurs (priorité de test recommandée)

1. **Scanner QR — messages d'erreur non différenciés** : billet déjà utilisé/annulé/expiré/hors ligne affichent tous "Ticket invalide ou introuvable" au lieu du message spécifique backend (BKG-002/003/004, NETWORK_TIMEOUT).
2. **Scanner QR — `valid: true` codé en dur** sur `PATCH /tickets/verify` dès réponse HTTP 2xx, sans lire le `status` réel ; en mode sans `tripId`, un ticket `USED` est affiché comme valide.
3. **iOS — `NSCameraUsageDescription` absente** d'`Info.plist` : risque de crash au premier accès caméra (scanner).
4. **Annulation/remboursement de réservation non implémentés** côté client (stub "bientôt disponible" côté passager, aucune action côté gare/partenaire).
5. **KYC covoiturage traitable uniquement depuis mobilipro** (UserDetailPage), pas depuis le back-office Angular.
6. **IDOR potentiel sur `PUT /partners/{id}`** : pas de vérification que l'id correspond au partenaire authentifié.
7. **Bug bottom nav ShellPartner** : `markAllRead()` se déclenche sur l'onglet Profil (index 4) au lieu de Notifications (index 3).
8. **Correctif Android Keystore absent de mobilipro** (présent uniquement dans mobile_app) — risque de blocage sur Keystore corrompu.
9. **Aucune gestion offline** : coupure réseau et session expirée produisent la même redirection vers `/login`, sans distinction pour l'utilisateur.
10. **Archivage de trajet "pro" purement local** (non persisté serveur), contrairement à l'archivage chauffeur qui, lui, est serveur.
11. **`EditTripPage` envoie `partnerId: 0`** au lieu du vrai partnerId — à vérifier si le backend l'ignore réellement en update.
12. **Messages d'erreur bruts (`'Erreur : $e'`)** non localisés sur plusieurs écrans (édition profil, gestion gares/chauffeurs/chefs de gare) au lieu des messages français mappés par code MOB-XXX.
13. **Rate limiting fail-open** si Redis indisponible ; IP résolue via `X-Forwarded-For` sans confiance de proxy.
14. **Deux fichiers `AdminGestionPage`** (`admin_gestion_page.dart` routé vs `_v2.dart` non routé mais fournissant les modèles partagés) — risque de confusion en maintenance/tests.
