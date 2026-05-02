# Documentation sécurité — Mobili

Vue **par thèmes** (pas un fourre-tout unique). Chaque fichier peut être lu indépendamment ; celui-ci sert d’**index** et de fil d’Ariane.

**Redis** (quotas multi-instance, cache futur, etc.) : dossier séparé — [Documentation Redis](../redis/README.md).

---

## Thèmes

### 1. Authentification & autorisation

- JWT stateless, cookie refresh, rôles et surfaces API.
- Fichier : [01-authentification-et-autorisation.md](01-authentification-et-autorisation.md)

### 2. Fichiers, uploads & médias sensibles

- Statique public limité (`/uploads/users`, `partners`, `vehicles`).
- KYC covoiturage, PDF, endpoint `GET /v1/media/private`.
- Fichier : [02-uploads-et-medias-sensibles.md](02-uploads-et-medias-sensibles.md)

### 3. Rate limiting & abus

- Filtre, tiers, IP / `X-Forwarded-For`, désactivation d’urgence.
- Suite Redis documentée à part : [Feuille de route quotas Redis](../redis/feuille-de-route-rate-limit.md).
- Fichier : [03-rate-limiting-et-abus.md](03-rate-limiting-et-abus.md)

### 4. Transport HTTP, CORS & en-têtes

- CORS par environnement, CSRF (API JWT), en-têtes de sécurité.
- Fichier : [04-transport-cors-et-en-tetes.md](04-transport-cors-et-en-tetes.md)

### 5. Validation entrées, multipart, secrets & webhooks

- Limites multipart, validation fichiers (images / PDF), secrets, paiements.
- Fichier : [05-validation-multipart-secrets-webhooks.md](05-validation-multipart-secrets-webhooks.md)

### 6. Checklist déploiement & QA

- Renvoi vers la release QA et rappels prioritaires.
- Fichier : [06-checklist-deploiement-et-qa.md](06-checklist-deploiement-et-qa.md)

---

## Voir aussi

- [README racine](../../README.md) — synthèse courte § Sécurité (pointe ici pour le détail).
- [ROADMAP](../../ROADMAP.md) — jalons industrialisation / durcissement.
- [Index général du dossier docs](../README.md).
