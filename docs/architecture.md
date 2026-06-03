# Architecture MOBILI

Document de référence : vue d’ensemble, stack, audit synthétique et **diagrammes Mermaid** (globaux puis par compartiment).

---

## 1. Synthèse structurelle

- **Pattern** : monolithe modulaire **Maven** (`mobili-core` + **`mobili-boot`** exécutable). Une seule API Spring Boot déployable ; le domaine métier vit surtout dans `mobili-boot` (`api/`, `module/`, `infrastructure/`).
- **Frontend** : workspace **Angular** — appli voyageur, appli **`mobili-business`**, lib **`mobili-shared`**.
- **Données** : **PostgreSQL** + migrations **Flyway** ; **Redis** optionnel (rate limiting distribué).
- **Paiement** : **FedaPay** (SDK Java + webhook + vérification côté serveur).

### Dossiers principaux (racine)

| Dossier | Rôle |
|---------|------|
| `backend/` | Reactor Maven : `mobili-core` (partagé léger), `mobili-boot` (REST, sécurité, JPA, Flyway). |
| `frontend/` | Angular : appli voyageur, `mobili-business`, `mobili-shared`, e2e Playwright. |
| `docs/` | Sécurité, Redis, QA, modularisation. |
| `scripts/` | `verify` (Maven + build + tests front). |
| `docker-compose.yml` | Dev front (container Angular + watch). |

---

## 2. Technologies clés

**Backend** : Java 21, Spring Boot 4.x, Spring Web MVC, Spring Security (JWT stateless), Spring Data JPA, PostgreSQL, Flyway, Redis (optionnel), JJWT, MapStruct, Lombok, Actuator + Prometheus, FedaPay (SDK), dotenv-java.

**Frontend** : Angular ~21, RxJS, TypeScript, intercepteurs HTTP, guards, Tailwind (outil), Playwright (e2e).

---

## 3. Patterns identifiables

Injection de dépendances (Spring / Angular), couche **service** transactionnelle (`@Transactional`), **repositories** Spring Data, **DTO + mappers**, filtre **JWT** + rate limit dans la chaîne Security, adaptation **FedaPay** via un service dédié, intercepteur front pour Bearer + refresh.

---

## 4. Audit synthétique (rappel)

- **Points d’attention lancement** : configuration FedaPay (environnement / URLs) à **externaliser** en prod ; dépendance SDK à **figer** (éviter `SNAPSHOT` Jitpack non reproductible).
- **Scalabilité** : activer **Redis** pour quotas globaux derrière load balancer.
- **Sécurité** : renforcer **idempotence** des confirmations paiement ; aligner stockage tokens client (mobile) avec les bonnes pratiques documentées dans le dépôt.

---

## 5. Diagrammes globaux

### 5.1 Contexte système

```mermaid
flowchart LR
  User((Utilisateur final))
  Admin((Admin / Exploitant))

  subgraph Mobili["Plateforme MOBILI"]
    FE[Frontend Angular]
    BE[API Spring Boot]
    DB[(PostgreSQL)]
    REDIS[(Redis optionnel)]
    FS[Fichiers uploads/]
  end

  FP[FedaPay]

  User --> FE
  Admin --> FE
  FE --> BE
  BE --> DB
  BE --> REDIS
  BE --> FS
  BE <--> FP
```

### 5.2 Conteneurs (applications + données)

```mermaid
flowchart TB
  subgraph Clients
    B[Navigateur / WebView]
  end

  subgraph "Frontend (workspace Angular)"
    PAX["Appli voyageur (frontend)"]
    BIZ["Appli mobili-business"]
    SHR["Lib mobili-shared"]
  end

  subgraph "Backend (Maven)"
    CORE["mobili-core (jar partagé)"]
    BOOT["mobili-boot (JAR exécutable)"]
    BOOT --> CORE
  end

  subgraph Données
    PG[(PostgreSQL)]
    R[(Redis)]
    UPL[/Répertoire uploads/]
  end

  EXT[FedaPay]

  B --> PAX
  B --> BIZ
  PAX --> SHR
  BIZ --> SHR
  PAX --> BOOT
  BIZ --> BOOT
  BOOT --> PG
  BOOT --> R
  BOOT --> UPL
  BOOT <--> EXT
```

### 5.3 Flux critique : auth → réservation → paiement → billets

```mermaid
sequenceDiagram
  participant Nav as Client Angular
  participant API as Spring Boot /v1
  participant DB as PostgreSQL
  participant FP as FedaPay

  Nav->>API: POST /v1/auth/login
  API->>DB: vérif utilisateur
  API-->>Nav: JWT + cookie refresh (httpOnly)

  Nav->>API: POST /v1/bookings (Bearer)
  API->>DB: réservation PENDING
  API-->>Nav: bookingId

  Nav->>API: POST /v1/payments/checkout/{bookingId}
  API->>FP: création transaction (SDK)
  FP-->>API: URL paiement + transactionId
  API->>DB: enregistrement transaction FedaPay
  API-->>Nav: { url }

  Nav->>FP: redirection paiement

  par Confirmation
    FP-->>API: POST /v1/payments/callback (secret)
    API->>DB: confirmFedaPayPayment + billets
    Nav->>API: POST /v1/payments/verify/{bookingId}
    API->>FP: relire statut transaction
    API->>DB: confirm si approuvé
  end

  Nav->>API: GET /v1/bookings/{id} (polling)
  API-->>Nav: CONFIRMED + détails
```

---

## 6. Compartiment : Frontend Angular

### 6.1 Deux applis + lib partagée

```mermaid
flowchart LR
  subgraph "projects/"
    MB["mobili-business"]
    MS["mobili-shared"]
    F["frontend (voyageur)"]
  end
  F --> MS
  MB --> MS
```

### 6.2 Structure interne `frontend/src/app`

```mermaid
flowchart TB
  subgraph App["frontend/src/app"]
    RT[app.routes.ts]
    CFG[configurations/]
    CORE[core/]
    FEAT[features/]
    SHR[shared/]
    LAY[layout/]
  end

  subgraph CoreDetail["core/"]
    GU[guards/]
    INT[interceptors JWT + refresh]
    SVC[services]
  end

  subgraph FeatDetail["features/"]
    AUTH[auth/]
    BOOK[bookings/]
    PAY[payment/]
    PART[partenaire/]
    GARE[gare/]
    ADM[admin/]
  end

  RT --> GU
  RT --> FEAT
  CORE --> GU
  CORE --> INT
  CORE --> SVC
  FEAT --> AUTH
  FEAT --> BOOK
  FEAT --> PAY
```

### 6.3 Chaîne HTTP client (intercepteur)

```mermaid
sequenceDiagram
  participant C as Composant / Service
  participant I as authInterceptor
  participant H as HttpClient
  participant API as Backend /v1

  C->>H: requête
  H->>I: intercepte
  I->>I: Authorization Bearer si token
  I->>API: forward
  API-->>I: 401 éventuel
  I->>I: refresh via cookie
  I->>API: retry
  I-->>C: réponse
```

---

## 7. Compartiment : Backend Spring Boot

### 7.1 Modules Maven

```mermaid
flowchart TB
  ROOT[backend/pom.xml reactor]
  CORE[mobili-core]
  BOOT[mobili-boot]

  ROOT --> CORE
  ROOT --> BOOT
  BOOT -->|dépend de| CORE
```

### 7.2 Couches dans `mobili-boot`

```mermaid
flowchart TB
  subgraph API["api/"]
    PASS[passenger/]
    PART[partner/]
    ADM[admin/]
  end

  subgraph MOD["module/"]
    U[user/]
    T[trip/]
    B[booking/ ticket/]
    P[payment/fedaPay/]
    N[notification/]
  end

  subgraph INF["infrastructure/"]
    SEC[security/]
    CFG[configuration/]
  end

  subgraph SHD["shared/"]
    ERR[MobiliError]
  end

  API --> MOD
  API --> INF
  MOD --> INF
  MOD --> SHD
```

### 7.3 Domaines `module/*` (aperçu)

```mermaid
flowchart LR
  subgraph Domain["module/*"]
    booking[booking]
    ticket[ticket]
    trip[trip]
    user[user]
    payment[payment/fedaPay]
  end

  booking --> ticket
  booking --> trip
  booking --> user
  booking --> payment
```

---

## 8. Compartiment : données & fichiers

### 8.1 Persistance

```mermaid
flowchart LR
  subgraph Spring
    JPA[Spring Data JPA]
    FW[Flyway]
  end
  PG[(PostgreSQL)]
  MIG["db/migration/V*.sql"]

  JPA --> PG
  FW --> MIG
  MIG --> PG
```

### 8.2 Uploads et médias

```mermaid
flowchart TB
  API[API / services]
  PUB["uploads publics filtrés (users, partners, vehicles)"]
  PRIV["GET /v1/media/private (JWT)"]

  API --> PUB
  API --> PRIV
```

### 8.3 Rate limiting

```mermaid
flowchart TB
  RL[Filtre + MobiliRateLimitStore]
  MEM[Mémoire JVM]
  REDIS[(Redis)]

  RL --> MEM
  RL -.->|profil redis-rate-limit| REDIS
```

---

## 9. Compartiment : FedaPay & paiement

### 9.1 Composants

```mermaid
flowchart LR
  PC[PaymentController]
  FS[FedaPayService]
  BS[BookingService]
  DB[(PostgreSQL)]

  PC --> FS
  PC --> BS
  BS --> DB
  FS --> FPAPI[FedaPay API]
```

### 9.2 Séquence paiement détaillée

```mermaid
sequenceDiagram
  autonumber
  participant Nav as Angular
  participant Pay as PaymentController
  participant Fed as FedaPayService
  participant FP as FedaPay
  participant BS as BookingService
  participant DB as PostgreSQL

  Nav->>Pay: POST /v1/payments/checkout/{bookingId}
  Pay->>BS: findById
  Pay->>Fed: createPaymentSession
  Fed->>FP: Transaction.create
  FP-->>Fed: lien + id transaction
  Pay->>BS: recordFedaPayTransactionId
  Pay-->>Nav: { url }

  Nav->>FP: paiement utilisateur

  FP-->>Pay: POST /v1/payments/callback
  Pay->>BS: confirmFedaPayPayment

  Nav->>Pay: POST /v1/payments/verify/{bookingId}
  Pay->>Fed: retrieve + statut
  Pay->>BS: confirmFedaPayPayment
  BS->>DB: CONFIRMED + tickets
```

---

## 10. Compartiment : sécurité

### 10.1 Chaîne de filtres

```mermaid
flowchart LR
  REQ[Requête HTTP]
  CORS[CORS]
  RL[Rate limit]
  JWT[JWT filter]
  CHAIN[Filtres Security]
  CTRL[Controllers]

  REQ --> CORS
  CORS --> RL
  RL --> JWT
  JWT --> CHAIN
  CHAIN --> CTRL
```

### 10.2 Modèle d’autorisation (résumé)

```mermaid
flowchart TB
  A[SecurityFilterChain — requestMatchers]
  B["@PreAuthorize — méthodes"]

  A --> R1[Chemins publics : auth, trips GET, webhook…]
  A --> R2[Rôles par préfixe]
  B --> R3["SpEL — ex. userId vs principal"]
```

---

## 11. Compartiment : développement Docker (front)

```mermaid
flowchart TB
  subgraph Host["Développeur"]
    SRC["./frontend"]
  end

  subgraph Docker
    CNT[Container frontend Angular]
    W[develop.watch sync]
  end

  SRC --> W
  W --> CNT
  P420["localhost:4200"] --> CNT
```

---

## Références code utiles

| Sujet | Emplacement indicatif |
|--------|------------------------|
| Chemins API centralisés | `backend/mobili-core/.../MobiliApiPaths.java` |
| Règles Security | `backend/mobili-boot/.../SecurityConfig.java` |
| Paiement / webhook | `backend/mobili-boot/.../payment/PaymentController.java` |
| Service FedaPay | `backend/mobili-boot/.../fedaPay/service/FedaPayService.java` |
| Confirmation + billets | `backend/mobili-boot/.../booking/service/BookingService.java` |

Pour affiner les diagrammes : [Mermaid Live Editor](https://mermaid.live).
