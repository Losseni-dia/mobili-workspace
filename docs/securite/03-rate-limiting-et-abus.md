# Sécurité — Rate limiting & abus

 [← Index sécurité](README.md)

## Synthèse

Un filtre servlet limite le débit sur les **surfaces anonymes sensibles** (auth, inscriptions, webhook paiement, etc.). Réponse **429** avec corps JSON en cas de dépassement.

## Sous-thèmes

### Composants

- [`MobiliAuthRateLimitFilter`](../../backend/mobili-boot/src/main/java/com/mobili/backend/infrastructure/security/ratelimit/MobiliAuthRateLimitFilter.java)
- [`MobiliRateLimitStore`](../../backend/mobili-boot/src/main/java/com/mobili/backend/infrastructure/security/ratelimit/MobiliRateLimitStore.java) — stockage **mémoire JVM**
- [`MobiliRateLimitProperties`](../../backend/mobili-boot/src/main/java/com/mobili/backend/infrastructure/configuration/MobiliRateLimitProperties.java) — préfixe `mobili.security.rate-limit.*`

### Activation / incident

- `mobili.security.rate-limit.enabled=true|false`
- En diagnostic ponctuel : désactiver temporairement (voir [RELEASE-QA](../RELEASE-QA-MOBILI.md)).

### Confiance « IP client »

- Utilisation du **premier hop** `X-Forwarded-For` lorsque présent — à n’actuer que si le proxy frontal est **de confiance** (réseau privé, LB managé).

### Multi-instance & Redis

- En **plusieurs JVM** derrière un load balancer, le store **mémoire** ne partage pas l’état : activer **Redis** avec le profil `redis-rate-limit` et `spring.data.redis.*` — voir [Documentation Redis](../redis/README.md).
- **Feuilles de route / impact** : [Feuille de route quotas](../redis/feuille-de-route-rate-limit.md), [**Importance & mesure d’impact**](../redis/importance-et-mesure-d-impact.md).
