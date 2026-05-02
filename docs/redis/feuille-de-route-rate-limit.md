> [← Documentation Redis](README.md) · [**Importance & comment mesurer l’impact**](importance-et-mesure-d-impact.md)

---

# Feuille de route — quotas API avec Redis (multi-instance)

Objectif : lorsque **plusieurs instances** de l’API Mobili tournent derrière un load balancer, les quotas actuels (mémoire JVM dans `MobiliRateLimitStore`) ne sont **pas partagés**. Redis fournit un état **centralisé** pour compter les requêtes par clé (IP, route, etc.).

---

## État actuel (référence)

- Composants : `MobiliAuthRateLimitFilter`, `MobiliRateLimitStore`, `MobiliRateLimitProperties`.
- **Par défaut** : stockage **mémoire JVM** (`ConcurrentHashMap`), purge planifiée — une JVM ou quotas « best effort » en multi-instance.
- **Option Redis** : même `MobiliRateLimitStore`, clés `INCR` + TTL si `mobili.security.rate-limit.redis.enabled=true` et client Redis disponible (profil `redis-rate-limit`).

---

## Phase 1 — Préparation (sans Redis)

1. **Métriques** : exposer un compteur (Micrometer / logs) des réponses **429** pour calibrer les seuils YAML avant migration — voir [Importance & mesure d’impact](importance-et-mesure-d-impact.md) § 2.3.
2. **Clé de quota** : formaliser la clé utilisée (ex. `tier + ':' + clientIp`) ; documenter la confiance en **X-Forwarded-For** (réseau / proxy uniquement).
3. **Feature flag** : garder `mobili.security.rate-limit.enabled` pour couper les quotas en incident.

---

## Phase 2 — Redis opérationnel

1. **Infrastructure** : déployer Redis (réseau privé, auth TLS selon l’offre : ElastiCache, Azure Cache, Memorystore, cluster K8s Bitnami, etc.).
2. **Secrets** : URL Redis via variables d’environnement (`REDIS_HOST`, `REDIS_PORT`, mot de passe), **jamais** en dur dans le dépôt.
3. **Spring Data Redis** : ajouter `spring-boot-starter-data-redis` au module `mobili-boot`, configuration `spring.data.redis.*`.

---

## Phase 3 — Implémentation technique — **fait dans le monolithe**

1. **Backend partagé** : `MobiliRateLimitStore` utilise **`StringRedisTemplate`** (`INCR` + `EXPIRE`) lorsque `mobili.security.rate-limit.redis.enabled=true` et que Spring expose un client Redis (profil `redis-rate-limit` + `spring.data.redis.*`).
2. **Repli** : si Redis désactivé → compteur mémoire JVM inchangé ; si erreur Redis → `allow-on-redis-failure=true` autorise la requête, sinon retombée mémoire.
3. **Tests / CI** : désactiver les repositories Redis par défaut (`spring.data.redis.repositories.enabled=false` dans `application.yml`).
4. **Reste optionnel** : métriques Micrometer dédiées, Testcontainers Redis pour tests d’intégration, **Bucket4j** + extension Redis si besoin de fenêtres plus fines.

---

## Phase 4 — Production

1. Basculer `MobiliRateLimitStore` (ou son successeur) sur Redis en **préprod** avec charge réaliste.
2. Surveiller latence Redis et erreurs de connexion (circuit breaker / désactivation contrôlée).
3. Ajuster `mobili.security.rate-limit.*` après observation du trafic réel.

---

## Hors périmètre immédiat

- Quotas par **utilisateur authentifié** (nécessite lecture JWT dans le filtre ou service métier).
- WAF / Cloudflare en frontal (complémentaire, pas exclusif à Redis).
