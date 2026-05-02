# Sécurité — Checklist déploiement & QA

 [← Index sécurité](README.md)

## Document principal

La checklist opérationnelle **release / QA** (domaines, cookies, build, BDD, observabilité, durcissements backend) est maintenue ici :

- **[Release — QA Mobili](../RELEASE-QA-MOBILI.md)**

## Rappels croisés (sécurité)

| Sujet | Référence détaillée |
|--------|---------------------|
| Uploads publics vs médias privés | [02 — Uploads & médias sensibles](02-uploads-et-medias-sensibles.md) |
| Rate limit & Redis | [03 — Rate limiting](03-rate-limiting-et-abus.md) → [Redis](../redis/README.md) |
| CORS / HTTPS | [04 — Transport & en-têtes](04-transport-cors-et-en-tetes.md) |
| Secrets & webhooks | [05 — Validation & secrets](05-validation-multipart-secrets-webhooks.md) |

## Tests automatisés

- E2E : voir [`docs/recette-e2e.md`](../recette-e2e.md) et scénarios CSV associés.
