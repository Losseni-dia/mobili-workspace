# AUDIT_FLUTTER_ACTUEL.md

> Généré le 2026-06-03 — basé uniquement sur le code existant dans `mobile_app/`

---

## 1. Stack & Dépendances

### Versions détectées
- **Flutter SDK** : >= 3.10.0
- **Dart SDK** : >= 3.0.0 < 4.0.0
- **Version app** : 1.0.0+1

### Dépendances runtime

| Package | Version | Rôle |
|---|---|---|
| `go_router` | ^13.2.0 | Navigation déclarative (routes, guards, shell) |
| `flutter_riverpod` | ^2.5.1 | State management global |
| `riverpod_annotation` | ^2.3.5 | Annotations `@riverpod` |
| `dio` | ^5.4.3 | Client HTTP |
| `dio_cookie_manager` | ^3.1.1 | Gestion cookie httpOnly (refresh token) |
| `cookie_jar` | ^4.0.8 | Stockage persistant des cookies sur disque |
| `hive_flutter` | ^1.1.0 | Cache local offline-first |
| `flutter_secure_storage` | ^9.0.0 | Stockage sécurisé du JWT (Keychain/Keystore) |
| `equatable` | ^2.0.5 | Value equality sur les modèles |
| `json_annotation` | ^4.9.0 | Annotations `@JsonSerializable` |
| `path_provider` | ^2.1.3 | Accès aux dossiers app (cookies, Hive) |
| `connectivity_plus` | ^6.0.3 | Détection état réseau (importé, non utilisé) |
| `intl` | ^0.19.0 | Formatage dates ISO 8601 |

### Dev dependencies

| Package | Version | Rôle |
|---|---|---|
| `build_runner` | ^2.4.9 | Générateur de code |
| `json_serializable` | ^6.8.0 | Génération `.g.dart` JSON |
| `riverpod_generator` | ^2.4.0 | Génération providers |
| `hive_generator` | ^2.0.1 | Génération adaptateurs Hive |

### Assets déclarés
- `assets/images/` — dossier déclaré
- `assets/icons/` — dossier déclaré
- ⚠️ **Polices non déclarées** : `app_text_styles.dart` référence `PlusJakartaSans` et `Inter` mais aucune entrée `fonts:` dans `pubspec.yaml` → fallback système au runtime

---

## 2. Architecture mise en place

### Structure de `lib/`

```
lib/
├── main.dart                         # Point d'entrée, init Hive + ApiClient + ProviderScope
├── temp_pages.dart                   # 14 stubs temporaires (voir section 3)
│
├── core/
│   ├── network/
│   │   └── api_client.dart           # Singleton Dio + 3 intercepteurs + constants URL
│   ├── models/
│   │   ├── auth_response.dart        # DTO réponse login/refresh
│   │   ├── auth_response.g.dart      # Généré (json_serializable)
│   │   ├── mobili_error.dart         # MobiliError (JSON) + MobiliException (typée)
│   │   ├── mobili_error.g.dart       # Généré
│   │   └── page_response.dart        # Wrapper générique Page<T> Spring Boot
│   ├── router/
│   │   ├── go_router.dart            # 20+ routes + guards + redirects
│   │   └── go_router.g.dart          # Généré (riverpod_generator)
│   └── theme/
│       ├── app_theme.dart            # ThemeData light + dark complets (Material 3)
│       ├── app_colors.dart           # Palette complète Mobili (#092990, #FFCC00…)
│       └── app_text_styles.dart      # Typographie Inter + PlusJakartaSans
│
├── features/
│   ├── auth/
│   │   ├── domain/models/
│   │   │   ├── profile_dto.dart      # Modèle utilisateur + helpers rôles
│   │   │   └── profile_dto.g.dart    # Généré
│   │   ├── data/
│   │   │   └── auth_service.dart     # 7 méthodes API auth (login, register, refresh…)
│   │   ├── providers/
│   │   │   └── auth_provider.dart    # AuthNotifier + AuthState + providers dérivés
│   │   └── presentation/pages/
│   │       ├── login_page.dart       # ✅ Formulaire connexion complet
│   │       └── register_page.dart    # ✅ Formulaire inscription 7 champs
│   │
│   ├── trips/
│   │   ├── domain/models/
│   │   │   ├── trip.dart             # Trip + LegFare (tarifs tronçon)
│   │   │   └── trip_stop.dart        # Arrêt/escale trajet
│   │   ├── data/
│   │   │   └── trip_service.dart     # API trips + cache Hive TTL 5 min
│   │   ├── providers/
│   │   │   └── trip_provider.dart    # Providers trips + BookingNotifier (state machine)
│   │   └── presentation/pages/
│   │       ├── trip_search_page.dart # ✅ Recherche + résultats + skeletons
│   │       └── trip_detail_page.dart # ⚠️ Affiche trip, pas de channel websocket
│   │
│   └── bookings/
│       ├── domain/models/
│       │   └── booking.dart          # Booking + PaymentResult
│       ├── data/
│       │   └── booking_service.dart  # API bookings + checkout + verify + poll
│       └── presentation/pages/
│           └── booking_page.dart     # ⚠️ Grille sièges + flux FedaPay (boarding hardcodé)
│
└── shared/widgets/
    ├── mobili_button.dart            # ✅ 5 variantes (primary/secondary/outlined/ghost/danger)
    ├── mobili_error_widget.dart      # ✅ Full-page + banner + field errors
    ├── mobili_loader.dart            # ✅ Spinner + skeleton + overlay
    └── empty_state_widget.dart       # ✅ 8 types d'états vides
```

### Pattern utilisé
**Riverpod 2.x** (flutter_riverpod 2.5.1 + riverpod_annotation)

- `AutoDisposeAsyncNotifier` pour auth (état async + dispose automatique)
- `StateNotifier` pour booking (state machine explicite)
- `FutureProvider.autoDispose.family` pour données par ID
- `StateProvider` pour paramètres de recherche
- Providers dérivés (`currentProfileProvider`, `isAuthenticatedProvider`)

### Navigation
**GoRouter 13.2.0** avec `StatefulShellRoute` (bottom nav 5 onglets)

- Provider : `goRouterProvider: AutoDisposeProvider<GoRouter>`
- Guards : redirect basé sur `authProvider` (unauthenticated → `/login?redirect=<uri>`)
- 20+ routes définies (voir section 3)

---

## 3. Ce qui est implémenté

### Auth

| Fichier | Ce qu'il fait | Statut |
|---|---|---|
| `auth/data/auth_service.dart` | login, logout, refresh, register (x3), getMe, getUserById | ✅ Complet |
| `auth/providers/auth_provider.dart` | AuthNotifier + AuthState (enum status) + providers dérivés | ✅ Complet |
| `auth/presentation/pages/login_page.dart` | Formulaire identifiant/mdp, erreurs API, loading, liens vers register | ✅ Complet |
| `auth/presentation/pages/register_page.dart` | Formulaire 7 champs, validators locaux, section labels, erreurs API | ✅ Complet |
| `auth/domain/models/profile_dto.dart` | Modèle utilisateur + helpers rôles (isAdmin, isPartner…) | ✅ Complet |

### Trips

| Fichier | Ce qu'il fait | Statut |
|---|---|---|
| `trips/domain/models/trip.dart` | Trip (9 champs) + LegFare + formatters | ✅ Complet |
| `trips/domain/models/trip_stop.dart` | TripStop (4 champs) + formattedTime | ✅ Complet |
| `trips/data/trip_service.dart` | getTrips, searchTrips, getTripById, getTripStops, getOccupiedSeats + cache Hive TTL 5 min | ✅ Complet |
| `trips/providers/trip_provider.dart` | 5 FutureProviders + TripSearchParams + BookingNotifier state machine | ✅ Complet |
| `trips/presentation/pages/trip_search_page.dart` | Form départ/arrivée/date/type, ListView résultats, skeletons, empty state, refresh | ✅ Complet |
| `trips/presentation/pages/trip_detail_page.dart` | Affiche infos trip + arrêts, bouton "Choisir siège" (disabled si 0 places) | ⚠️ Partiel |

### Bookings

| Fichier | Ce qu'il fait | Statut |
|---|---|---|
| `bookings/domain/models/booking.dart` | Booking (8 champs) + PaymentResult | ✅ Complet |
| `bookings/data/booking_service.dart` | createBooking, getBooking, getBookingsForUser, checkout, verifyPayment, pollUntilConfirmed | ✅ Complet |
| `bookings/presentation/pages/booking_page.dart` | GridView sièges (occupé/libre/sélectionné) + createAndPay + launchUrl FedaPay + polling verify | ⚠️ Partiel |

### Core

| Fichier | Ce qu'il fait | Statut |
|---|---|---|
| `core/network/api_client.dart` | Singleton Dio + CookieManager + AuthInterceptor (inject Bearer + auto-refresh 401) + ErrorInterceptor | ✅ Complet |
| `core/models/auth_response.dart` | DTO token + login + id + hasPartner | ✅ Complet |
| `core/models/mobili_error.dart` | MobiliError JSON + MobiliException typée (12 codes) + localisation FR | ✅ Complet |
| `core/models/page_response.dart` | Wrapper générique Page<T> Spring Boot + helpers (isFirst, isLast…) | ✅ Complet |
| `core/router/go_router.dart` | 20+ routes + StatefulShellRoute + guards redirect | ✅ Complet |
| `core/theme/app_theme.dart` | ThemeData light + dark Material 3 complets | ✅ Complet |
| `core/theme/app_colors.dart` | Palette Mobili complète + dark mode + gradients + shadows | ✅ Complet |
| `core/theme/app_text_styles.dart` | Inter + PlusJakartaSans, 15+ styles, helpers | ✅ Complet |

### Shared widgets

| Fichier | Ce qu'il fait | Statut |
|---|---|---|
| `shared/widgets/mobili_button.dart` | 5 variantes × 3 tailles + loading + disabled + gradient gold | ✅ Complet |
| `shared/widgets/mobili_error_widget.dart` | MobiliErrorData + full-page + banner + field errors MOB-003 | ✅ Complet |
| `shared/widgets/mobili_loader.dart` | Spinner + skeleton box + skeleton listes + overlay paiement | ✅ Complet |
| `shared/widgets/empty_state_widget.dart` | 8 types (trips, bookings, search, offline…) + version compacte | ✅ Complet |

### Stubs (temp_pages.dart)

Ces pages sont des stubs `Center(Text(...))` sans fonctionnalité :

| Page | Route |
|---|---|
| `RegisterCompanyPage` | `/register-company` |
| `RegisterChauffeurPage` | `/register-chauffeur` |
| `TripsListPage` | `/` (accueil) |
| `TripChannelPage` | `/trips/:id/channel` |
| `TripStopsPage` | — (stub en dehors router) |
| `BookingDetailPage` | `/my-bookings/:id` |
| `MyBookingsPage` | `/my-bookings` |
| `PaymentWebviewPage` | `/payments/:id/checkout` |
| `PaymentResultPage` | `/payments/:id/result` |
| `MyTicketsPage` | `/profile/tickets` |
| `TicketDetailPage` | `/profile/tickets/:id` |
| `NotificationsPage` | `/notifications` |
| `PartnersListPage` | `/partners` |
| `PartnerDetailPage` | `/partners/:id` |
| `ProfilePage` | `/profile` |

---

## 4. Couche réseau

### Client HTTP
**Dio 5.4.3** — singleton `ApiClient`

- **Base URL dev** : `http://10.0.2.2:8080/v1` (émulateur Android)
- **Base URL prod** : placeholder non renseigné
- **Timeouts** : connect 15s / receive 30s / send 30s

### Intercepteurs (ordre d'exécution)

1. **CookieManager** — applique le cookie `MOBILI_REFRESH` (PersistCookieJar) sur chaque requête
2. **`_AuthInterceptor`** — injecte `Authorization: Bearer {token}` + détecte 401 → refresh auto + retry
3. **`_ErrorInterceptor`** — normalise toutes les erreurs HTTP → `MobiliException`

### Gestion du refresh token (cookie httpOnly)
✅ Implémentée avec protection anti-boucle infinie (`_isRefreshing` guard) :
1. 401 reçu → `_tryRefresh()` via instance Dio séparée (sans intercepteur auth)
2. POST `/auth/refresh` avec cookie MOBILI_REFRESH
3. Si succès → `saveToken()` + retry requête originale
4. Si échec → `clearSession()` (déconnexion)

### Modèles DTOs Dart (liste exhaustive)

| Modèle | Champs clés | Format sérialisation |
|---|---|---|
| `AuthResponse` | `token`, `login`, `id`, `hasPartner?` | `json_serializable` |
| `ProfileDto` | `id`, `firstname`, `lastname`, `email`, `login`, `roles[]`, `enabled`, `avatarUrl?` | `json_serializable` |
| `Trip` | `id`, `departureCity`, `arrivalCity`, `departureTime`, `arrivalTime?`, `totalSeats`, `availableSeats`, `priceXof`, `transportType?`, `partnerName?`, `legFares[]?`, `vehicleImageUrl?` | `fromJson` manuel |
| `LegFare` | `fromCity`, `toCity`, `priceXof` | `fromJson` manuel |
| `TripStop` | `id`, `cityName`, `scheduledTime?`, `stopIndex?` | `fromJson` manuel |
| `Booking` | `id`, `tripId`, `userId`, `seatNumber`, `status`, `boardingStopIndex?`, `alightingStopIndex?`, `createdAt?` | `fromJson` manuel |
| `PaymentResult` | `success`, `status` | `fromJson` manuel |
| `MobiliError` | `timestamp`, `status`, `errorCode`, `message?`, `path?`, `errors?` | `json_serializable` |
| `PageResponse<T>` | `content[]`, `totalElements`, `totalPages`, `number`, `size` | `fromJson` générique |
| `CreateBookingRequest` | `tripId`, `seatNumber`, `boardingStopIndex`, `alightingStopIndex` | `toJson` manuel |

### Endpoints Spring Boot appelés

```
POST  /auth/login
POST  /auth/logout
POST  /auth/refresh
POST  /auth/register                          (multipart)
POST  /auth/register-company                  (multipart)
POST  /auth/register-carpool-chauffeur        (multipart, 4 fichiers KYC)
GET   /auth/me
GET   /auth/{id}

GET   /trips?transportType=
GET   /trips/search?departure=&arrival=&date=&transportType=
GET   /trips/{id}
GET   /trips/{id}/stops

GET   /bookings/trips/{tripId}/occupied-seats?boardingStopIndex=&alightingStopIndex=
POST  /bookings
GET   /bookings/{id}
GET   /bookings/user/{userId}

POST  /payments/checkout/{bookingId}          → {url}
POST  /payments/verify/{bookingId}            → {success, status}
```

---

## 5. Authentification

### Login
✅ Implémenté — `LoginPage` → `authProvider.login()` → `AuthService.login()` → POST `/auth/login`

### Stockage JWT
- **Access token** : `FlutterSecureStorage` (iOS Keychain, Android Keystore)
- **Refresh token** : Cookie httpOnly `MOBILI_REFRESH` via `PersistCookieJar` (`/app_documents/.cookies`)

### Refresh token
✅ Géré automatiquement dans `_AuthInterceptor` — déclenché sur 401, instance Dio séparée, guard anti-boucle

### Guards / Redirections
✅ Implémentés dans `go_router.dart` :
- Pages protégées (`/my-bookings`, `/notifications`, `/profile`, `/payments/*`, `/profile/tickets/*`) → `/login?redirect=<uri>` si non authentifié
- Pages auth (`/login`, `/register`, `/register-*`) → `/` si déjà authentifié

### Statut session au démarrage
`AuthNotifier.build()` appelle `getMe()` pour vérifier le token existant → `authenticated` ou `unauthenticated`

---

## 6. Ce qui manque

### Fonctionnalités absentes (par rapport à une app Mobili complète)

#### Trajets
- ❌ **Page d'accueil / liste des trajets** (`TripsListPage` est un stub vide)
- ❌ **Page arrêts du trajet** (`TripStopsPage` stub — les données existent dans le service)
- ❌ **Channel temps réel** (`TripChannelPage` stub — WebSocket non implémenté)
- ❌ **Pagination** — `PageResponse<T>` existant mais non utilisé dans les listes

#### Réservations
- ❌ **Mes réservations** (`MyBookingsPage` stub)
- ❌ **Détail réservation** (`BookingDetailPage` stub)
- ❌ **Tickets / billets** (`MyTicketsPage`, `TicketDetailPage` stubs)
- ❌ **Sélection boarding/alighting stop** — hardcodé à 0/1 dans `booking_page.dart`

#### Paiement
- ❌ **WebView FedaPay** (`PaymentWebviewPage` stub) — actuellement `launchUrl` externe sans fallback
- ❌ **Page résultat paiement** (`PaymentResultPage` stub)

#### Profil utilisateur
- ❌ **Page profil** (`ProfilePage` stub)
- ❌ **Édition profil** — non prévu
- ❌ **Upload avatar** — `register()` supporte `avatarFile?` mais pas d'UI

#### Partenaires
- ❌ **Liste partenaires** (`PartnersListPage` stub)
- ❌ **Détail partenaire** (`PartnerDetailPage` stub)

#### Notifications
- ❌ **Notifications** (`NotificationsPage` stub)
- ❌ **Push notifications** — aucun package FCM/OneSignal

#### Inscriptions
- ❌ **Inscription compagnie** (`RegisterCompanyPage` stub) — `authService` prêt
- ❌ **Inscription chauffeur carpool** (`RegisterChauffeurPage` stub) — `authService` prêt (4 fichiers KYC)

#### Offline / UX réseau
- ❌ **Détection hors ligne** — `connectivity_plus` importé mais non utilisé
- ❌ **Snackbar offline** / page "Pas de connexion"
- ❌ **Retry automatique** sur perte de connexion

---

## 7. Problèmes détectés

### Bugs visibles

| # | Fichier | Problème |
|---|---|---|
| 1 | `booking_page.dart` | `boardingStopIndex` et `alightingStopIndex` hardcodés à 0/1 — invalide pour trajets multi-stops |
| 2 | `booking_page.dart` | `launchUrl()` sans gestion d'erreur si l'URL est invalide ou si l'app FedaPay n'est pas installée |
| 3 | `temp_pages.dart` | `TripsListPage` est un stub → la route `/` (accueil) affiche juste du texte |
| 4 | `trip_provider.dart` | `occupiedSeatsProvider` re-fetch à chaque rebuild — pas de polling contrôlé, peut surcharger le backend |

### Mauvaises pratiques

| # | Fichier | Problème |
|---|---|---|
| 5 | `pubspec.yaml` | Polices `PlusJakartaSans` et `Inter` référencées dans le code mais non déclarées → fallback silencieux |
| 6 | `core/network/api_client.dart` | URL prod `https://<domaine-prod>/v1` est un placeholder — risque d'envoyer en dev en production |
| 7 | `temp_pages.dart` | `ShellPage` (bottom nav) est dans les stubs temporaires — à sortir dans un fichier propre |
| 8 | `trip_provider.dart` | Mix `StateNotifier` (booking) + `AutoDisposeAsyncNotifier` (auth) — incohérence de style Riverpod |

### Incompatibilités potentielles avec le backend Spring

| # | Endpoint | Problème potentiel |
|---|---|---|
| 9 | `GET /trips/search` | Le DTO search attend `date` mais le format exact (ISO 8601 ? `yyyy-MM-dd` ?) non validé côté Flutter |
| 10 | `POST /bookings` | `boardingStopIndex` et `alightingStopIndex` envoyés toujours à 0/1 — peut échouer si le backend valide les indices |
| 11 | `POST /payments/verify/{bookingId}` | Polling 10× max à 3s — si le backend met > 30s à confirmer le paiement FedaPay, le flow échoue silencieusement |
| 12 | `GET /bookings/trips/{tripId}/occupied-seats` | `boardingStopIndex` et `alightingStopIndex` sont optionnels côté Flutter mais peut-être requis côté backend |

---

## 8. Prochaine étape recommandée

### Priorité 1 — Implémenter `TripsListPage` (accueil)

C'est le point d'entrée de l'app (`/`). Sans elle, l'utilisateur authentifié arrive sur un écran vide.

**Ce qui est déjà prêt et ne demande que du wiring UI :**
- `tripsProvider` → retourne `List<Trip>` (getTrips ou searchTrips selon params)
- `MobiliTripCardSkeleton` → skeleton loader prêt
- `EmptyStateWidget(type: MobiliEmptyType.trips)` → état vide prêt
- `MobiliErrorWidget` / `MobiliErrorBanner` → gestion erreurs prête
- Navigation vers `TripDetailPage` déjà configurée dans le router

**Travail estimé :** 1–2 jours — `ListView` + `RefreshIndicator` + filtres transport type + navigation.

### Priorité 2 — Corriger le boarding/alighting hardcodé dans `BookingPage`

Le booking flow est presque complet mais invalide pour les trajets multi-stops. Corriger `boardingStopIndex`/`alightingStopIndex` en les faisant sélectionner depuis les arrêts réels (`tripStopsProvider`).

### Priorité 3 — Implémenter `MyBookingsPage`

L'utilisateur n'a aucun moyen de voir ses réservations passées. Le service `BookingService.getBookingsForUser()` est prêt.
