# Feuille de route — Mobili

Document **orienté prochaine étape** : il complète le [README](README.md) (vision, backlog table Fxx, règles de qualité). **À mettre à jour** quand une phase est bouclée ou qu’on repriorise.

**Dernière révision** : mai 2026.

---

## Où on en est (court)

| Domaine | État | Détail |
|--------|------|--------|
| **CI/CD & cloud** | Hors dépôt | Pas de workflows GitHub ni Docker dans ce dépôt (cours — à ajouter toi-même si besoin). |
| **Métier prioritaire** | En cours | Recherche multi-arrêts (F30) partiellement livré ; **descente & siège libéré** (F31), **résa segmentée** et **anti surbooking** restent le cœur du backlog (voir [README — backlog](README.md#backlog-global-ordre-logique-de-travail)). |
| **Prod** | Non | Pas d’hébergement / domaine / secrets d’environnement finalisés ; durcissements restants listés dans [docs/securite/](docs/securite/README.md) (CORS prod, dépendances, observabilité). |

---

## Prochaines phases (suggestion d’ordre)

### 1. Produit cœur (bloquant pour une offre crédible)

- Finaliser / industrialiser la **recherche** sur lignes longues (segments, jeux de données, tests e2e).
- Spécifier et implémenter la **libération de siège** après descente (qui déclenche : chauffeur, gare, système ?).
- **Anti surbooking** cohérent avec les segments.
- Côté **front** : parcours recherche → résa → paiement stables (mobile-first).

*Réf. fonctionnelle* : F30, F31, F32, colonnes de la [table de suivi](README.md#suivi-des-fonctionnalités).

### 2. Industrialisation & déploiement (à faire en dehors du code cours)

- **Environnements** : au minimum *staging* (API + front sur domaines dédiés), variables et secrets hors `.env` local.
- **Profil Spring `staging`** : [`application-staging.yml`](backend/mobili-boot/src/main/resources/application-staging.yml) — CORS front recette, secrets via env.
- **Front** : [`app.env.config.ts`](frontend/src/app/app.env.config.ts) — adapter domaines et URL d’API au déploiement ; WebView : override via [`index.html`](frontend/src/index.html) si besoin.
- **Pipelines** : GitHub Actions, GitLab CI, ou autre — build `mvn`, `ng build`, publication d’artefacts ou images, selon ton cours.
- **Observabilité** : logs structurés, healthcheck, alertes de base (même légères).

### 3. Durcissement avant ouverture large

- CORS / origines par environnement ; suivre [docs/securite/04-transport-cors-et-en-tetes.md](docs/securite/04-transport-cors-et-en-tetes.md).
- **Uploads** : périmètre public réduit + médias sensibles via API — [docs/securite/02-uploads-et-medias-sensibles.md](docs/securite/02-uploads-et-medias-sensibles.md).
- **Rate limiting** : mémoire JVM OK mono-instance ; multi-instance → feuille de route [Redis — quotas](docs/redis/feuille-de-route-rate-limit.md) et guide [**importance / mesure d’impact**](docs/redis/importance-et-mesure-d-impact.md).
- Suivi des **dépendances** (Maven, npm) et correctifs de sécurité.

### 4. Mobile (quand le web + API prod sont stables)

- Piste décrite dans le [README — Capacitor](README.md#mobile--capacitor-ionic-ou-natif-) : prérequis HTTPS, `ng build` stable, puis `cap add` / sync. Pas de calendrier figé ici : dépend de la **traction** et des contraintes store.

---

## Phases modularisation (rappel)

Voir [docs/FEUILLE-DE-ROUTE-MODULARISATION.md](docs/FEUILLE-DE-ROUTE-MODULARISATION.md) pour le détail **Mobili voyageur / Mobili Business** (deux façades, `mobili-core` + `mobili-boot`).

### Deux offres — guide dédié

- Feuille de route **détaillée** (phases 0–4, prérequis, risques, liens vers le code) : [docs/FEUILLE-DE-ROUTE-MODULARISATION.md](docs/FEUILLE-DE-ROUTE-MODULARISATION.md).  
- **Phases 0, 1.0 et 2 (code)** : considérées **clôturées dans le référentiel** — tableau synthétique dans le [README racine](README.md#phases-modularisation). **Phases 3–4** (deux JARs / double hébergement) restent **optionnelles**.  
- **État code (sans déployer)** : deux apps Angular (**4200** voyageur, **mobili-business** 4201), `mobili-core` Maven (`MobiliApiPaths`), `mobili-boot` ; vérif locale `npm run verify` ; E2E voyageur + Business : `npm run verify:e2e:all` depuis la racine ou `npm run e2e:all` dans `frontend/`. Le **déploiement** reste hors dépôt tant que tu ne branches pas ton infra (cours).  
- Distincte des **priorités F30 / F31** (recherche, siège libéré) : pourra progresser en parallèle dès cadrage produit, sans supplanter le cœur métier court terme.

---

## Ce qu’on ne met pas ici (volontairement)

- **Liste exhaustive des écrans** : voir le README (cartographie routes, table Fxx).
- **Historique** : [CHANGELOG](CHANGELOG.md) si alimenté.
- **Détails techniques d’une feature** : plutôt `docs/` + README ciblé.

---

## Revue de la feuille de route (rituel léger)

À chaque grosse livraison ou fin de trimestre : (1) cocher ce qui est fait dans ce document ; (2) ajuster l’ordre des phases ; (3) noter en une ligne la **prochaine** priorité #1 en équipe.

---

*Document à tenir à jour avec la réalité du dépôt et de ton cours (infra).*
