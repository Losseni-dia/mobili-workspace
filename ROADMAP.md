# Feuille de route — Mobili

Document **orienté prochaine étape** : il complète le [README](README.md) (vision, backlog table Fxx, règles de qualité). **À mettre à jour** quand une phase est bouclée ou qu’on repriorise.

**Dernière révision** : avril 2026.

---

## Où on en est (court)

| Domaine | État | Détail |
|--------|------|--------|
| **CI GitHub** | Fait | Workflow `CI` : tests backend (PostgreSQL de service) + build & tests frontend sur `main` / `develop`. `mvnw` exécutable + script shell sur le runner Linux. |
| **CD** | Partiel | Build image Docker `backend` ; job « déploiement » = **placeholder** (messages dans le log) — **pas d’AWS branché** tant que les secrets / architecture ne sont pas figés. |
| **Métier prioritaire** | En cours | Recherche multi-arrêts (F30) partiellement livré ; **descente & siège libéré** (F31), **résa segmentée** et **anti surbooking** restent le cœur du backlog (voir [README — backlog](README.md#backlog-global-ordre-logique-de-travail)). |
| **Prod** | Non | Pas d’hébergement / domaine / secrets d’environnement finalisés ; durcissement sécurité (CORS, uploads, rate limit) listé dans le [README — sécurité](README.md#sécurité-robustesse-et-ordre-de-déploiement). |

---

## Prochaines phases (suggestion d’ordre)

### 1. Produit cœur (bloquant pour une offre crédible)

- Finaliser / industrialiser la **recherche** sur lignes longues (segments, jeux de données, tests e2e).
- Spécifier et implémenter la **libération de siège** après descente (qui déclenche : chauffeur, gare, système ?).
- **Anti surbooking** cohérent avec les segments.
- Côté **front** : parcours recherche → résa → paiement stables (mobile-first).

*Réf. fonctionnelle* : F30, F31, F32, colonnes de la [table de suivi](README.md#suivi-des-fonctionnalités).

### 2. Industrialisation & déploiement

- **Environnements** : au minimum *staging* (API + front sur domaines dédiés), variables et secrets hors `.env` local.
- **CD** : remplacer le placeholder dans [`.github/workflows/cd.yml`](.github/workflows/cd.yml) par une chaîne concrète (ex. ECR + ECS, ou autre) ; OIDC plutôt que clés longue durée si possible.
- **Frontend** : pipeline de build (artefact `ng build`) et hébergement statique (S3 + CloudFront, Netlify, etc.) aligné sur l’URL API.
- **Observabilité** : logs structurés, healthcheck, alertes de base (même légères).

### 3. Durcissement avant ouverture large

- CORS / origines par environnement, **uploads** (`/uploads/**`) moins permissifs.
- **Rate limiting** sur login et endpoints sensibles.
- Suivi des **dépendances** (Maven, npm) et correctifs de sécurité.

### 4. Mobile (quand le web + API prod sont stables)

- Piste décrite dans le [README — Capacitor](README.md#mobile--capacitor-ionic-ou-natif-) : prérequis HTTPS, `ng build` stable, puis `cap add` / sync. Pas de calendrier figé ici : dépend de la **traction** et des contraintes store.

---

## Ce qu’on ne met pas ici (volontairement)

- **Liste exhaustive des écrans** : voir le README (cartographie routes, table Fxx).
- **Historique** : [CHANGELOG](CHANGELOG.md) si alimenté.
- **Détails techniques d’une feature** : plutôt `docs/` + README ciblé.

---

## Revue de la feuille de route (rituel léger)

À chaque grosse livraison ou fin de trimestre : (1) cocher ce qui est fait dans ce document ; (2) ajuster l’ordre des phases ; (3) noter en une ligne la **prochaine** priorité #1 en équipe.
