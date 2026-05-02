# Documentation Redis — Mobili

Ce dossier regroupe **tout ce qui concerne Redis** dans le projet (feuilles de route, choix d’infra, conventions de clés). Il est **distinct** de la [documentation sécurité générale](../securite/README.md), qui décrit le comportement métier (JWT, uploads, rate limit côté produit) sans imposer un backend de stockage particulier.

## Activation (rate limit distribué)

1. Démarrer Redis (ex. Docker avec profil `redis`, voir [`docker-compose.yml`](../../docker-compose.yml)).
2. Activer le **profil Spring** `redis-rate-limit` (charge `application-redis-rate-limit.yml`) **en plus** du profil habituel, ex. :
   - `SPRING_PROFILES_ACTIVE=dev,redis-rate-limit`
3. Pointer le client vers l’hôte Redis :
   - `SPRING_DATA_REDIS_HOST` (ex. `localhost` ou `redis` dans Compose)
   - `SPRING_DATA_REDIS_PORT` (défaut `6379`)
   - `SPRING_DATA_REDIS_PASSWORD` si besoin

Exemple local après `docker compose --profile redis up -d redis` :

```bash
export SPRING_PROFILES_ACTIVE=dev,redis-rate-limit
export SPRING_DATA_REDIS_HOST=localhost
```

### Propriétés YAML (`mobili.security.rate-limit.redis`)

| Clé | Défaut | Rôle |
|-----|--------|------|
| `enabled` | `false` | Active le backend Redis dans `MobiliRateLimitStore`. **Mis à `true` par le profil `redis-rate-limit`.** |
| `key-prefix` | `mobili:rl` | Préfixe des clés Redis (`INCR`). |
| `allow-on-redis-failure` | `true` | Erreur Redis : autoriser la requête ; si `false`, retombée sur le compteur **mémoire** JVM. |

## Implémentation (référentiel)

- Dépendance : `spring-boot-starter-data-redis` (`mobili-boot`).
- Logique : [`MobiliRateLimitStore`](../../backend/mobili-boot/src/main/java/com/mobili/backend/infrastructure/security/ratelimit/MobiliRateLimitStore.java) — `INCR` + `EXPIRE` 120 s sur une clé par `(tier, IP, minute)` ; repli mémoire si Redis désactivé ou erreur selon `allow-on-redis-failure`.

## Contenu actuel

| Document | Objet |
|----------|--------|
| [**Importance & mesure d’impact**](importance-et-mesure-d-impact.md) | **Pourquoi** Redis pour les quotas (multi-instance), **comment** observer l’effet (429, charge, métriques). |
| [Feuille de route — quotas multi-instance (rate limit)](feuille-de-route-rate-limit.md) | Phases infra / prod et alternatives (Bucket4j, etc.). |

## Pistes documentaires futures (à créer ici)

- Cache lecture (catalogue trajets, données peu volatiles), avec TTL et invalidation.
- Verrous distribués ou files légères si le métier le requiert.
- Convention des préfixes de clés (`mobili:*`), environnements (dev / staging / prod).

Pour la **checklist QA** qui mentionne Redis en complément du rate limit : voir aussi [Release QA Mobili](../RELEASE-QA-MOBILI.md).
