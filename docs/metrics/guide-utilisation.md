# Manuel d’utilisation — métriques Mobili (Prometheus / Grafana / Actuator)

Ce guide décrit comment **collecter** et **visualiser** les métriques de l’API Spring Boot **Mobili** en environnement de développement local.

---

## 1. Ce qui est en place dans le projet

| Composant | Rôle |
|-----------|------|
| **Spring Boot Actuator** | Endpoints techniques (`/actuator/health`, `/actuator/metrics`, …). |
| **Micrometer + registre Prometheus** | Exposition des métriques au format Prometheus sur **`/actuator/prometheus`**. |
| **Prometheus** (Docker, profil `metrics`) | Scrape périodique de cette URL et stockage des séries temporelles. |
| **Grafana** (Docker, profil `metrics`) | Interface web : exploration et tableaux de bord branchés sur Prometheus. |

**Important :** l’exposition HTTP de **`prometheus`** (et une partie des autres endpoints sensibles) est configurée pour le **profil Spring `dev`** (`application-dev.yml`). En production, seuls les endpoints strictement nécessaires restent exposés (voir `application-prod.yml`).

---

## 2. Ports et conventions

| Contexte | URL API | Port |
|----------|---------|------|
| **Maven / IDE** (profil `dev`) | `http://localhost:8080` | **8080** (défaut `server.port` dans `application.yml`). |
| **Conteneur Docker** (`docker compose`) | `http://localhost:8081` | **8081** sur l’hôte → **8080** dans le conteneur (`API_PORT` par défaut dans `docker-compose.yml`). |

Le front Angular doit pointer vers **8080** en dev local ; vers **8081** si vous testez uniquement contre l’API Docker.

Autres services utiles :

| Service | URL habituelle |
|---------|----------------|
| Prometheus UI | `http://localhost:9090` |
| Grafana | `http://localhost:3000` |

---

## 3. Prérequis

1. **JDK 21**, Maven, Docker Desktop (ou équivalent).
2. Variables d’environnement habituelles pour l’API (`JWT_SECRET`, base PostgreSQL, etc.) — voir README racine et `.env`.
3. Pour les quotas Redis distribués (optionnel) : Redis + profils `dev,redis-rate-limit` (voir `docs/redis/`).

---

## 4. Démarrer la stack métriques (Docker)

À la **racine du dépôt** (là où se trouve `docker-compose.yml`) :

```bash
docker compose --profile metrics up -d
```

Cela démarre **Prometheus** et **Grafana**. Postgres et l’API peuvent être démarrés séparément selon votre flux :

- API **locale** : `cd backend/mobili-boot && mvn spring-boot:run` (profil `dev`).
- API **Docker** : `docker compose up -d api` (après Postgres healthy).

Redémarrer Prometheus après modification de `deploy/prometheus/prometheus.yml` :

```bash
docker compose --profile metrics restart prometheus
```

---

## 5. Endpoints Actuator (API)

Avec le profil **`dev`** :

| Méthode | Chemin | Usage |
|---------|--------|--------|
| GET | `/actuator` | Liste des endpoints exposés (JSON). |
| GET | `/actuator/health` | Santé globale (ex. `{"status":"UP", …}`). |
| GET | `/actuator/metrics` | Liste des noms de métriques. |
| GET | `/actuator/metrics/{nom}` | Détail d’une métrique (JSON). |
| GET | `/actuator/prometheus` | **Corps texte** au format Prometheus (consommé par le scraper). |

En navigateur ou avec `curl` :

```bash
curl -s http://localhost:8080/actuator/health
curl -s http://localhost:8080/actuator/prometheus | head
```

Si l’API tourne dans Docker :

```bash
curl -s http://localhost:8081/actuator/health
```

**Sécurité :** `GET /`, `/actuator/health` et `/actuator/prometheus` sont accessibles sans JWT pour faciliter le scrape et les sondes ; le reste de l’API métier reste sous **`/v1`** avec les règles habituelles.

---

## 6. Prometheus — vérifier le scrape

1. Ouvrir **`http://localhost:9090`**.
2. Menu **Status → Targets**.

Deux jobs sont définis dans `deploy/prometheus/prometheus.yml` :

| Job | Cible | Quand il est **UP** |
|-----|--------|---------------------|
| `mobili-api-host` | `host.docker.internal:8080` | API lancée **sur la machine** (Maven / IDE) sur le port **8080**. |
| `mobili-api-docker` | `api:8080` | Service **`api`** du même `docker compose`, joignable sur le réseau Docker interne. |

**Comportement normal :** souvent **un seul** des deux est UP selon que vous développez en local ou uniquement en conteneurs. Si vous changez le port Maven (autre que 8080), adaptez la cible du job `mobili-api-host` dans `prometheus.yml`.

Tester une requête instantanée dans Prometheus (**Graph**) :

```promql
up{job=~"mobili-api.*"}
```

---

## 7. Grafana — première connexion

1. Ouvrir **`http://localhost:3000`**.
2. Identifiants par défaut : **`admin`** / **`admin`** (modifiable via variables d’environnement `GRAFANA_ADMIN_USER` et `GRAFANA_ADMIN_PASSWORD` dans `.env` à la racine du projet).
3. Une datasource **Prometheus** est provisionnée automatiquement (`deploy/grafana/provisioning/datasources/`), URL interne `http://prometheus:9090`.

---

## 8. Grafana Explore — exemples de requêtes (PromQL)

Menu **Explore**, datasource **Prometheus**.

### Présence de données JVM / processus

```promql
process_cpu_usage
```

```promql
jvm_memory_used_bytes
```

### Requêtes HTTP (Micrometer)

Les noms exacts peuvent varier selon la version Spring Boot ; les préfixes courants sont `http_server_requests_*`.

**Requêtes terminées (histogramme / compteur) :**

```promql
rate(http_server_requests_seconds_count[5m])
```

**Requêtes encore actives (connexion ouverte, ex. SSE) :**

```promql
http_server_requests_active_seconds_count
```

### Astuces interface

- Ajuster la plage de temps en haut à droite (**Last 15 minutes**, etc.).
- Passer en onglet **Metrics browser** pour parcourir les séries disponibles après quelques scrapes.

---

## 9. Tableau de bord dans Grafana (déjà fourni)

Un dashboard **`Mobili API — métriques`** est **provisionné automatiquement** au démarrage du conteneur Grafana :

1. Connexion à **`http://localhost:3000`**.
2. Menu **Dashboards** → dossier **Mobili** → **Mobili API — métriques**.

Un second tableau **métier (SQL)** est disponible dans le même dossier : **Mobili — métriques métier (SQL)** — voir la section *Dashboard métier (PostgreSQL)* plus bas dans ce guide.

Sur ce dashboard **technique** tu trouves notamment : scrape UP, CPU JVM, heap HTTP (débit par URI), requêtes actives, latence p95, threads, uptime. Les séries filtrent les jobs Prometheus **`mobili-api-host`** et **`mobili-api-docker`** (regex `mobili-api.*`).

Le fichier source JSON est [`deploy/grafana/dashboards/mobili-api-overview.json`](../../deploy/grafana/dashboards/mobili-api-overview.json) ; tu peux l’éditer ou exporter depuis Grafana après modifications UI.

---

## 10. Dashboard métier (PostgreSQL)

Le fichier **`deploy/grafana/dashboards/mobili-business-overview.json`** provisionne **Mobili — métriques métier (SQL)** — dossier Grafana **Mobili**.

### Connexion par défaut : Postgres **local** (`mobili_db`)

Le conteneur Grafana n’est pas sur la même pile réseau « localhost » que ton PC : il joint Postgres via **`host.docker.internal`** (Docker Desktop Windows/Mac). Variables dans **`.env`** à la racine (voir **`.env.example`**) :

| Variable | Rôle (défaut dans `docker-compose`) |
|----------|-------------------------------------|
| **`GRAFANA_POSTGRES_URL`** | Hôte:port du Postgres sur la machine — `host.docker.internal:5432` |
| **`GRAFANA_POSTGRES_DB`** | Nom de la base Maven locale — **`mobili_db`** |
| **`GRAFANA_POSTGRES_USER`** | Optionnel : sinon **=`DB_USERNAME`** (souvent `postgres`) |
| **`GRAFANA_POSTGRES_PASSWORD`** | Optionnel : sinon **=`DB_PASSWORD`**. À renseigner si le mot de passe du rôle Postgres **sur Windows** diffère de celui utilisé par Maven (erreur `pq: authentification par mot de passe échouée`). |

La datasource provisionnée **`Mobili PostgreSQL`** lit **`GRAFANA_POSTGRES_*`** injectées par **`docker-compose`** dans **`deploy/grafana/provisioning/datasources/postgres.yml`** (substitution au démarrage de Grafana).

Après modification du `.env`, redémarrer Grafana :

```bash
docker compose --profile metrics up -d grafana --force-recreate
```

Vérifier dans Grafana : **Connections → Data sources → Mobili PostgreSQL → Save & test**.

Si la connexion est refusée : Postgres doit écouter sur une interface joignable depuis Docker (**`listen_addresses`** dans `postgresql.conf`, souvent `*` ou au moins le port exposé), et **`pg_hba.conf`** doit autoriser le sous-réseau Docker / l’hôte (selon ton installation).

### Port 5432 sur l’hôte vs Postgres Docker

Si le service **`postgres`** du compose publie le port **5432** sur Windows, alors **`host.docker.internal:5432`** depuis Grafana pointe vers **ce conteneur**, pas vers Postgres Windows. Dans ce cas, dans **`.env`**, définir par exemple **`POSTGRES_PORT=5433`** pour que **5432** reste celui de Postgres Windows (`mobili_db`), comme recommandé dans **`.env.example`**.

### UID datasource, nom affiché et dashboards SQL

Le fichier **`deploy/grafana/provisioning/datasources/postgres.yml`** provisionne une datasource nommée **`Mobili PostgreSQL`** avec l’**UID `mobili-postgres`**. Le dashboard **`Mobili — métriques métier (SQL)`** référence **exclusivement cet UID** dans ses panneaux.

- Si tu crées d’autres sources PostgreSQL dans l’UI (ex. nom générique **`grafana-postgresql-datasource`**), les panneaux du dashboard **mobili-business-overview** **ne les utilisent pas** tant que tu ne changes pas le datasource de chaque panneau.
- Après correction des identifiants, ouvre bien la datasource dont l’UID est **`mobili-postgres`** (souvent affichée sous le nom **Mobili PostgreSQL**) → **Save & test**.

### Ne pas mettre `localhost` comme hôte (Grafana dans Docker)

Depuis le **conteneur** Grafana, **`localhost` ou `127.0.0.1`** désigne le **conteneur lui-même**, pas ta machine hôte. Pour joindre Postgres **installé sur Windows**, l’hôte doit être **`host.docker.internal`** et le port celui où écoute Postgres Windows (**`5432`** en général), avec la base **`mobili_db`**.

### Réglages UI utiles (PostgreSQL)

| Champ | Valeur typique (dev local, Grafana dans Docker) |
|-------|---------------------------------------------------|
| Hôte / URL | **`host.docker.internal:5432`** (ou hôte + port séparés équivalents) |
| Base | **`mobili_db`** |
| Utilisateur / mot de passe | **`DB_USERNAME` / `DB_PASSWORD`** (ou surcharges **`GRAFANA_POSTGRES_*`**) |
| TLS/SSL | **`disable`** (aligné sur `sslmode: disable` dans `postgres.yml`) |
| Version PostgreSQL | **14**, **15** ou **16** selon ton serveur — pas une version très ancienne type 9.3 |

### Vérifier les variables dans le conteneur Grafana

Les variables **`GRAFANA_POSTGRES_*`** sont injectées au **démarrage** du conteneur par Compose. Pour les afficher **à l’intérieur** du conteneur, évite que ton shell **hôte** (Git Bash, etc.) remplace **`$VAR`** avant `docker compose exec` : utilise des **guillemets simples** autour de la commande passée à `sh -c`.

**Correct (Git Bash / shell POSIX) :**

```bash
docker compose --profile metrics exec grafana sh -c 'printf "%s\n" "USER=$GRAFANA_POSTGRES_USER" "URL=$GRAFANA_POSTGRES_URL" "DB=$GRAFANA_POSTGRES_DB"'
```

**Incorrect** (les `$…` sont évalués sur l’hôte, souvent vides) :

```bash
docker compose exec grafana sh -c "echo $GRAFANA_POSTGRES_USER"
```

Sous **PowerShell**, on peut aussi utiliser **`docker compose … exec grafana env | findstr GRAFANA_POSTGRES`** (ou équivalent).

### Explore (SQL) vs Save & test

- **Save & test** : **Connections → Data sources →** (ta source PostgreSQL) — valide login, réseau et droits.
- **Explore** : pour tester une requête SQL ; choisir la datasource **`mobili-postgres`** / **Mobili PostgreSQL**, bouton **Add query**, mode **Code**, par exemple `SELECT COUNT(*) FROM stations WHERE active = true;`, format **Table**, puis **Run query**. Tant qu’aucune requête n’est lancée, **Explore** peut afficher **No data** sans que ce soit une erreur.

### Supprimer des datasources PostgreSQL en double

1. **Connections → Data sources** → cliquer le **nom** de la source à retirer.
2. Descendre en bas de la page → **Delete**.

Les sources **uniquement créées dans l’UI** peuvent être supprimées ainsi. Une datasource **provisionnée** par fichier sous **`deploy/grafana/provisioning/`** peut être **réinjectée** au prochain redémarrage de Grafana : garde une source cohérente avec **`postgres.yml`** ou adapte les fichiers du dépôt avant de supprimer la ligne provisionnée.

### Alternative : Postgres dans Docker Compose (`mobili`)

Pour pointer vers le service **`postgres`** du compose (base **`mobili`**) :

```env
GRAFANA_POSTGRES_URL=postgres:5432
GRAFANA_POSTGRES_DB=mobili
GRAFANA_POSTGRES_USER=mobili
GRAFANA_POSTGRES_PASSWORD=mobili
```

(Aligner le mot de passe sur **`DB_PASSWORD`** du compose.)

### Utilisateur lecture seule `grafana_ro` (optionnel, Postgres Docker)

Utile seulement si Grafana lit la base **`mobili`** dans le conteneur Postgres : script **`deploy/postgres/init/01-grafana-readonly.sh`** (nouveau volume) ou **`deploy/postgres/manual-grafana-readonly.sql`**.

**Sécurité :** ne pas exposer Grafana sur Internet avec des identifiants faibles.

---

## 11. Importer d’autres tableaux de bord


1. **Dashboards → New → Import**.
2. Saisir un ID public adapté JVM / Spring Boot (ex. recherche Grafana « JVM Micrometer » ; les métriques peuvent nécessiter un léger ajustement des panneaux).
3. Choisir la datasource **Prometheus**.

Les dashboards génériques ne reflètent pas forcément des métriques **métier Mobili** ; ils servent surtout à JVM, CPU, HTTP et file descriptors.

---

## 12. Dépannage

| Symptôme | Pistes |
|----------|--------|
| Dashboard SQL **erreur connexion** / « No data » | **Connections → Data sources → Mobili PostgreSQL → Save & test.** Vérifier `GRAFANA_POSTGRES_*` dans `.env` (URL `host.docker.internal:5432`, base `mobili_db`). User/mot de passe : par défaut **`DB_USERNAME` / `DB_PASSWORD`** ; sinon **`GRAFANA_POSTGRES_USER` / `GRAFANA_POSTGRES_PASSWORD`**. Voir `listen_addresses` / `pg_hba.conf` si refus TCP. |
| **`pq: authentification par mot de passe échouée`** (utilisateur `postgres`) | Le mot de passe du rôle **`postgres` sur Postgres Windows** ne correspond pas à **`DB_PASSWORD`** injecté dans Grafana. Aligner avec `ALTER USER postgres WITH PASSWORD '…'` ou définir **`GRAFANA_POSTGRES_PASSWORD`** (et redémarrer Grafana). |
| Plusieurs sources PostgreSQL ; panneaux SQL en erreur alors qu’une source « marche » | Les dashboards provisionnés utilisent l’UID **`mobili-postgres`**. Éditer **Mobili PostgreSQL** / **`mobili-postgres`** → **Save & test**, ou réassigner la datasource sur chaque panneau. Éviter **`localhost`** comme hôte pour Grafana dans Docker. |
| Navigateur : **`POST …/api/ds/query` — 400 Bad Request** | Ouvrir l’onglet **Network** → réponse JSON du `query` : souvent erreur SQL ou échec connexion Postgres. Les messages **`Request was aborted` / `status: -1`** dans la console peuvent être **sans lien** (requête annulée par navigation). |
| Dashboard métier : graphiques vides, stats OK | Élargir la **plage de temps** ; les séries réservations utilisent **`$__timeFilter(created_at)`** sur **`bookings.created_at`**. |
| Target Prometheus **DOWN** | API arrêtée ; mauvais port pour `mobili-api-host` ; firewall ; profil Spring sans exposition `prometheus`. |
| Grafana « No data » (Prometheus / JVM) | Fenêtre temporelle trop courte ; aucun trafic HTTP récent pour les métriques concernées ; vérifier **Explore** sur `process_cpu_usage`. |
| **Port 8080 déjà utilisé** (Maven) | Arrêter l’autre processus (`mobili-api` Docker, autre Spring Boot) ou définir `SERVER_PORT=8082` pour Maven uniquement. |
| Conflit Docker **8081** | Changer `API_PORT` dans `.env` si besoin. |

---

## 13. Références fichiers

| Fichier | Rôle |
|---------|------|
| `backend/mobili-boot/pom.xml` | Dépendances `spring-boot-starter-actuator`, `micrometer-registry-prometheus`. |
| `backend/mobili-boot/src/main/resources/application-dev.yml` | `management.endpoints.web.exposure.include` incluant `prometheus`. |
| `backend/mobili-boot/.../SecurityConfig.java` | Accès anonyme contrôlé à `/actuator/health` et `/actuator/prometheus`. |
| `deploy/prometheus/prometheus.yml` | Jobs et cibles de scrape. |
| `deploy/grafana/provisioning/datasources/prometheus.yml` | Datasource Prometheus (`uid` **mobili-prometheus**). |
| `deploy/grafana/provisioning/dashboards/mobili.yml` | Chargement auto des JSON dans **Dashboards → Mobili**. |
| `deploy/grafana/provisioning/datasources/postgres.yml` | Datasource **Mobili PostgreSQL** (**UID `mobili-postgres`**, variables **`GRAFANA_POSTGRES_*`** → **`mobili_db`** par défaut). |
| `deploy/grafana/dashboards/mobili-business-overview.json` | Dashboard **Mobili — métriques métier (SQL)**. |
| `deploy/postgres/init/01-grafana-readonly.sh` | Création **grafana_ro** au premier init Postgres (nouveau volume). |
| `deploy/postgres/manual-grafana-readonly.sql` | Création **grafana_ro** sur base déjà existante. |
| `deploy/grafana/dashboards/mobili-api-overview.json` | Dashboard **Mobili API — métriques**. |
| `docker-compose.yml` | Services `prometheus`, `grafana`, profil `metrics`, variable `API_PORT`. |

---

*Document rédigé pour l’équipe Mobili — développement local uniquement pour la partie exposition Prometheus détaillée ci-dessus.*
