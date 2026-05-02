# Redis — Pourquoi c’est important & comment voir l’impact

 [← Documentation Redis](README.md) · [Feuille de route technique — quotas](feuille-de-route-rate-limit.md)

Ce document complète la **feuille de route** : il fixe la **valeur métier / sécurité** de Redis pour Mobili et des **méthodes concrètes** pour observer l’effet **avant** et **après** mise en œuvre.

---

## 1. Pourquoi Redis pour les quotas (importance)

### 1.1 Problème en multi-instance (sans Redis)

Le débit est limité par instance avec **`MobiliRateLimitStore`** : une `ConcurrentHashMap` **dans chaque JVM** (`tier:name()` + IP comme clé logique).

| Situation | Conséquence |
|-----------|-------------|
| **1 instance API** | Le quota YAML (`mobili.security.rate-limit.*`) correspond bien au comportement attendu **par IP et par minute**. |
| **N instances** derrière un load balancer | Chaque instance maintient **son propre compteur** pour la même IP. Une attaque ou un pic légitime peut, en pratique, obtenir **jusqu’à environ N fois** la limite configurée (requêtes réparties sur des JVM différentes). |
| **Rotation / scaling** | Un nouvel instance démarre avec des compteurs **vides** : léger effet de « fenêtre ouverte » tant que les anciennes entrées ne sont pas encore équilibrées côté trafic. |

Donc : **sans état partagé**, le rate limiting reste utile en mono-instance ou comme frein léger, mais **ne garantit plus le même niveau de protection** lorsque vous montez en disponibilité (plusieurs pods / VMs).

### 1.2 Ce que Redis apporte

- **Un seul compteur par clé** (ex. IP + tier + fenêtre temporelle) pour **toute la flotte** API.
- Des quotas **alignés sur l’intention** du YAML : « X tentatives par minute **pour cette IP** », pas « X par minute **par instance** ».
- Base pour **évoluer** (quotas par utilisateur authentifié, autres clés) sans multiplier les hacks JVM.

Redis n’est pas obligatoire **tant que** vous n’avez **qu’une instance** API en production ; il devient **prioritaire** dès que **≥ 2 instances** servent le même trafic utilisateur sur les routes protégées par `MobiliAuthRateLimitFilter`.

### 1.3 Redis au-delà des quotas (vision dossier `docs/redis`)

Les usages futurs possibles (cache catalogue, verrous légers, etc.) ont leur **propre ROI** ; ils sont listés dans [README Redis](README.md). Ce guide se concentre sur **l’impact mesurable du rate limit distribué**.

---

## 2. Comment voir l’impact (méthodes)

### 2.1 Indicateurs métier / sécurité à suivre

| Indicateur | Interprétation |
|------------|----------------|
| **Taux de réponses HTTP 429** sur `/v1/auth/*`, webhook paiement, etc. | Proportion de requêtes **bloquées** par le filtre (voir corps JSON `code: RATE_LIMITED`). |
| **Répartition 429 par instance** (avant Redis) | Si vous voyez des 429 **surtout sur une instance** alors que la charge est équilibrée, ou peu de 429 **globalement** malgré un flood distribué, c’est cohérent avec des **compteurs locaux**. |
| **Latence P95/P99** des routes protégées | Après Redis : surveiller une **hausse faible** acceptable ; une dégradation forte = problème réseau / Redis / timeouts. |
| **Erreurs de connexion Redis** | Indisponibilité ou saturation : risque de **fail-open** (selon implémentation future) ou de **perte de protection** — à traiter par circuit breaker et alerting. |

### 2.2 Aujourd’hui (code actuel — sans métrique Micrometer dédiée)

Le filtre **`MobiliAuthRateLimitFilter`** renvoie **429** avec un JSON fixe ; il **ne publie pas** encore un compteur Micrometer nommé dans ce dépôt.

**Mesures possibles sans changer le code :**

1. **Logs d’accès** au reverse proxy (nginx, ALB, CloudFront, etc.) : filtrer `status=429` et agrégations par `upstream` / instance — pour voir si les blocages sont **hétérogènes** entre instances.
2. **Logs applicatifs** : si vous ajoutez temporairement une ligne de log au refus (ou utilisez un niveau DEBUG ciblé), agréger les occurrences **par tier** (`LOGIN_REFRESH`, `REGISTER`, …).
3. **Tests de charge ciblés** (préprod, compte technique) :
   - Mono-instance : dépasser le seuil → vous devez obtenir des **429**.
   - Multi-instance **sans Redis** : même charge totale répartie → vous pouvez observer **moins de 429 qu’attendu** (budget multiplié).
   - Après Redis : même scénario → **429 alignés** avec la limite globale attendue.

### 2.3 Recommandé avant migration Redis (Phase 1 de la feuille de route)

Pour rendre l’impact **visible en continu** :

- Exposer des **métriques** (Micrometer / Prometheus / Datadog, etc.) :
  - compteur **`mobili.security.rate_limit.blocked`** avec tags **`tier`**, **`http.status=429`** (ou équivalent) ;
  - idéalement un histogramme de latence **Redis** une fois l’intégration faite.
- **Tableaux de bord** : courbes 429/min par tier ; corrélation avec nombre d’instances API.

Sans ces métriques, la « preuve » de l’écart multi-instance reste **surtout qualitative** (tests de charge + logs).

### 2.4 Après adoption Redis

| Où regarder | Quoi |
|-------------|------|
| **Observabilité applicative** | Compteurs 429 ; temps passé dans `tryConsume` Redis ; erreurs timeout. |
| **Redis lui-même** | Latence (`LATENCY DOCTOR` / métriques managées), connexions, mémoire, évictions (à éviter pour ce cas d’usage avec TTL courts). |
| **Comparaison avant / après** | Même scénario de charge, **même nombre d’instances** : comparer le nombre de **429 par minute** et la **courbe de succès login** — après Redis, les abus distribués doivent produire **plus** de 429 pour une même charge malveillante répartie. |

### 2.5 Pièges qui faussent la lecture

- **`X-Forwarded-For`** : si mal configuré, **toutes** les requêtes peuvent avoir la **même IP** (LB) ou une IP **incorrecte** → quotas incohérents. La confiance dans la première IP doit suivre la doc [§ Rate limiting](../securite/03-rate-limiting-et-abus.md).
- **Désactivation du rate limit** (`mobili.security.rate-limit.enabled=false`) : les métriques 429 tombent à zéro **sans** que la menace ait disparu — à signaler en runbook incident.

---

## 3. Synthèse une ligne

| Question | Réponse courte |
|----------|----------------|
| **Quand Redis devient important ?** | Dès **plusieurs instances** API derrière un LB pour les routes limitées par `MobiliAuthRateLimitFilter`. |
| **Comment voir l’impact aujourd’hui ?** | Agréger les **429** (proxy / logs), comparer multi-instance **sans** Redis vs attente théorique ; tests de charge. |
| **Comment mieux le voir demain ?** | **Compteurs Micrometer** + dashboards ; après Redis, métriques **Redis + latence** des `tryConsume`. |
