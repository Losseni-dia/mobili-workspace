# Index — dossier `docs/`

Point d’entrée pour la documentation **hors README racine**, organisée par **domaine**.

## Architecture & produit

| Document | Contenu |
|----------|---------|
| [CADRAGE-PHASE-0.md](CADRAGE-PHASE-0.md) | Cadrage phase 0 |
| [FEUILLE-DE-ROUTE-MODULARISATION.md](FEUILLE-DE-ROUTE-MODULARISATION.md) | Modularisation monolithe / doubles apps |
| [gemini-mobili-aws-roadmap.md](gemini-mobili-aws-roadmap.md) | Briefing infra AWS |

## Sécurité (par thèmes)

→ **[securite/README.md](securite/README.md)** — authentification, uploads & médias sensibles, rate limit, CORS, validation, checklist QA.

## Métriques & observabilité

| Document | Contenu |
|----------|---------|
| [metrics/README.md](metrics/README.md) | Index (Prometheus, Grafana, Actuator). |
| [metrics/guide-utilisation.md](metrics/guide-utilisation.md) | **Manuel** : démarrage, ports, Actuator, PromQL, dépannage. |

## Redis (documentation dédiée)

| Document | Contenu |
|----------|---------|
| [redis/README.md](redis/README.md) | Index Redis (quotas, extensions futures). |
| [redis/importance-et-mesure-d-impact.md](redis/importance-et-mesure-d-impact.md) | **Pourquoi** Redis pour les quotas multi-instance, **comment** voir l’impact (429, charge, métriques). |
| [redis/feuille-de-route-rate-limit.md](redis/feuille-de-route-rate-limit.md) | Phases techniques (préparation → prod). |

## Qualité & recette

| Document | Contenu |
|----------|---------|
| [RELEASE-QA-MOBILI.md](RELEASE-QA-MOBILI.md) | Checklist release / durcissements backend |
| [recette-e2e.md](recette-e2e.md) | Recette E2E |
| `qa-scenarios-15*.csv` | Scénarios QA |

## Recherche & segments

| Document | Contenu |
|----------|---------|
| [recherche-segments.md](recherche-segments.md) | Segments recherche |

---

*Pour la vision produit, backlog table Fxx et guides Capacitor : voir le [README racine](../README.md).*
