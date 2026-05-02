# Release — QA Mobili (voyageurs + Business)

## Synthèse

La recette manuelle sur les **15 scénarios** initiaux (`qa-scenarios-15.csv`) a été **validée**. Les deux applications front (site voyageurs et Mobili Business), couplées à l’API, se comportent de façon cohérente sur les parcours d’authentification, les redirections cross-origine, l’inscription société, l’espace covoiturage sur Business et l’inscription gare sur le site voyageurs.

## Avant passage en production (checklist technique)

- **Domaines** : `apiUrl`, `businessWebBase`, `travelerWebBase` et origines CORS alignés sur les URL réelles (pas `localhost`).
- **Cookies / JWT** : `SameSite`, `Secure` en HTTPS ; cookie refresh lisible par l’API sur le même site ou configuration explicite cross-subdomain selon votre hébergement.
- **Variables d’environnement** : secrets (JWT, webhooks paiement) distincts prod / hors prod ; aucun secret dans le dépôt.
- **Build** : `ng build --configuration production` (ou équivalent) pour chaque front ; `mvn -Pprod` ou pipeline CI vert sur la branche release.
- **Base de données** : migrations Flyway appliquées ; sauvegarde avant mise en ligne.
- **Observabilité** : logs erreurs API, santé actuator si utilisé ; plan de rollback (image / artefact précédent).

## Durcissements backend (post-audit)

- **Quota débit** (`mobili.security.rate-limit.*`) sur login / refresh / logout, inscriptions (dont société et gare POST), prévisualisation code gare (GET), webhook paiement — réponse **429** JSON si dépassement (fenêtre ~1 minute / IP ; premier hop `X-Forwarded-For` si présent — faire confiance au réseau / proxy). Détail : [docs/securite/03-rate-limiting-et-abus.md](securite/03-rate-limiting-et-abus.md). **Backend Redis optionnel** (quotas globaux multi-instance) : profil Spring `redis-rate-limit` + `spring.data.redis.*` — [docs/redis/README.md](redis/README.md), [**importance & mesure d’impact**](redis/importance-et-mesure-d-impact.md).
- **Entêtes HTTP** : `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy` restrictive sur les réponses filtrées par Spring Security.
- **Multipart** : plafonds Spring (`max-file-size` 15 Mo, `max-request-size` 70 Mo).
- **Upload fichiers** :
  - **Images** (avatars, logos, photos trajets catalogue) : contrôle taille (`mobili.backend.upload.max-bytes-per-file`), types MIME (JPEG / PNG / WebP) et **signature magique** avant écriture disque ; diffusion statique **uniquement** sous `/uploads/users/**`, `/uploads/partners/**`, `/uploads/vehicles/**`.
  - **Médias sensibles** (KYC covoiturage : pièces ID image ou PDF, photo conducteur / véhicule ; dossier `documents-folder` ; préfixes `sensitive/**` et anciens `covoiturage-*`) : **pas** d’URL statique publique ; lecture **`GET /v1/media/private?rel=…`** avec JWT et contrôle d’accès — voir [docs/securite/02-uploads-et-medias-sensibles.md](securite/02-uploads-et-medias-sensibles.md).
  - **PDF** métier : `saveDocument`, limite `max-bytes-per-document`.
- **Production** : exposition actuator limitée à `health` (sans détails) dans `application-prod.yml`.

Désactiver temporairement les quotas : `mobili.security.rate-limit.enabled=false`.
