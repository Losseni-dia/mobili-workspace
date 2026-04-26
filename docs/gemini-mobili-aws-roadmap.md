# Briefing complet — Projet **Mobili** + déploiement **AWS** (recette / staging)

**Usage** : coller ce document (ou le fichier) à un assistant (ex. Gemini) pour te guider **pas à pas** dans la console AWS et le DNS, sans re-explainer le contexte produit à chaque fois.

**Dernière mise à jour** : avril 2026. Dépôt : monorepo `mobili` (backend Spring Boot + frontend Angular).

---

## 1. Produit

- **Mobili** : plateforme de mobilité interurbaine (réservation, billets, partenaires, rôles voyageur / partenaire / chauffeur / admin / gare, paiement FedaPay, etc.).
- **Cible géographique** : lancement en Afrique (dont Côte d’Ivoire).
- **Objectif de déploiement actuel** : environnement de **recette** (**staging**), **pas** la production finale : tests HTTPS, intégration, futur test **Capacitor** (app mobile), avec **FedaPay en sandbox**.

---

## 2. Stack technique (déjà dans le code)

| Couche | Technologie |
|--------|-------------|
| Backend | **Spring Boot 4** / **Java 21**, API préfixe **`/v1`**, **PostgreSQL**, **Flyway** |
| Frontend | **Angular** (build production = fichiers statiques) |
| Paiement | **FedaPay** (clés **sandbox** en recette) |
| CI | **GitHub Actions** : tests Maven + tests/build Angular (workflow `ci.yml`) |
| Conteneur API | `backend/Dockerfile` (image Docker pour déploiement type ECS/EC2) |
| Hébergement cible (recette) | **AWS** : **S3 + CloudFront** (front), **ALB + ECS/Beanstalk/EC2** (API), **RDS PostgreSQL** (base recette) |

Le **code** est prêt côté **configuration staging** (URLs et CORS) — il reste l’**infra** AWS + **DNS** + variables d’environnement sur l’hébergeur.

---

## 3. Noms de domaine (décision actuelle)

- **Domaine racine** : **`mobili.ci`** — acheté / en cours d’activation chez le registrar **Safaricloud** (gestion **DNS** chez eux, serveurs de type `NS1.SAFARICLOUD.AFRICA`).
- **Hébergement application** : **AWS** (le domaine n’est **pas** chez AWS Route 53 pour l’enregistrement, mais on **pointe** des **CNAME** / enregistrements depuis la zone `mobili.ci` vers les cibles **CloudFront** et **ALB** AWS.

### URLs cibles (recette) — **alignées sur le code versionné**

| Rôle | URL publique | Note |
|------|----------------|------|
| **Front (SPA Angular)** | `https://int.mobili.ci` (+ option `https://www.int.mobili.ci`) | C’est l’**origine** des pages ; le **CORS** côté API autorise **ces hôtes**, pas l’URL de l’API. |
| **API (Spring Boot)** | `https://api.int.mobili.ci` | Préfixe API côté client : **`/v1`** (URL complète type `https://api.int.mobili.ci/v1/...`). |
| **Webhook FedaPay (sandbox)** | `https://api.int.mobili.ci/v1/payments/callback` | À configurer sur le dashboard FedaPay quand l’URL répond en HTTPS. |

Fichiers du dépôt concernés (pour cohérence) :

- `frontend/src/app/app.env.config.ts` — `staging` : domaines `int.mobili.ci` / `www.int.mobili.ci`, `apiUrl: https://api.int.mobili.ci/v1`
- `backend/src/main/resources/application-staging.yml` — CORS : `https://int.mobili.ci`, `https://www.int.mobili.ci`, + localhost:4200 + origines usuelles Capacitor
- `frontend/src/index.html` — optionnel : `meta name="mobili-api-base"` ou `window.__MOBILI_API_URL__` pour forcer l’URL API (WebView)
- `frontend/src/app/configurations/services/configuration.service.ts` — priorité override meta / `window` puis détection par hostname
- **Profil Spring recette** : `SPRING_PROFILES_ACTIVE=staging` sur l’API déployée

---

## 4. Régions AWS (règles à respecter)

- **Région par défaut** pour l’**API, RDS, ALB, S3, certificat de l’API** : **`eu-west-3` (Europe — Paris)**. C’est celle qu’on utilise dans la console quand on travaille sur ces services.
- **Exception obligatoire** : le **certificat SSL utilisé par CloudFront** pour le **custom domaine** du front (`int.mobili.ci`) doit être créé dans **ACM** en **`us-east-1` (N. Virginia — USA)**. C’est une **contrainte AWS** (CloudFront ne prend que des certificats ACM produits en `us-east-1`).

En résumé : **2 certificats ACM** typiquement — un en `us-east-1` (front / CloudFront), un en `eu-west-3` (API / ALB).

---

## 5. Ordre logique d’exécution (feuille de route infra)

1. S’assurer que **`mobili.ci`** est **actif** et que la **zone DNS** est modifiable (Safaricloud).
2. **ACM `us-east-1`** : demander un certificat **public** pour `int.mobili.ci` (et `www.int.mobili.ci` si besoin) — **validation DNS** (CNAME de validation à créer **chez Safaricloud**). Attendre **Issued**.
3. **ACM `eu-west-3`** : demander un certificat pour **`api.int.mobili.ci`** — même logique **DNS**. Attendre **Issued**.
4. **S3** (`eu-west-3`) : bucket **privé** pour les assets du `ng build` (pas d’ouverture publique “site web” naïf ; accès via **CloudFront** avec **OAC** / configuration recommandée).
5. **CloudFront** : distribution, origine S3, **domaines alternatifs** = `int.mobili.ci`, certificat = celui d’`us-east-1`, default root `index.html`, **erreurs 403/404** → 200 sur `/index.html` (SPA Angular). Noter l’URL `*.cloudfront.net`.
6. **DNS Safaricloud** : **CNAME** `int` (et `www.int` si besoin) → cible = nom de domaine **CloudFront** (pas `https://` dans le champ cible).
7. **RDS** `eu-west-3` : PostgreSQL pour recette ; réseau **VPC** + **Security Groups** (souvent pas d’exposition internet directe de la base).
8. **API** : déployer l’image **Docker** (`backend/`) vers **ECR** + **ECS Fargate** (ou **Elastic Beanstalk** / **EC2** + ALB) ; **ALB** en **HTTPS** avec le cert `api.int.mobili.ci` ; variables d’environnement (voir section 6).
9. **DNS** : **CNAME** `api.int` → nom DNS de l’**ALB** (souvent `xxxxx.eu-west-3.elb.amazonaws.com`).
10. Vérifier dans le navigateur : front sur `https://int.mobili.ci`, appels API sur `https://api.int.mobili.ci/v1/...` sans **erreur CORS** ; enregistrer le **webhook** FedaPay.
11. (Option) **CI/CD** : le fichier `.github/workflows/cd.yml` ne fait aujourd’hui que vérifier le **build Docker** — à étendre plus tard (**ECR push**, déploiement ECS, **OIDC** IAM, etc.).

---

## 6. Variables d’environnement côté API (recette)

Sur la **task** ECS, **Beanstalk**, ou service équivalent, prévoir notamment (noms cohérents avec le projet) :

- `SPRING_PROFILES_ACTIVE=staging`
- `DB_URL` / `DB_USERNAME` / `DB_PASSWORD` (pointant vers **RDS**)
- `JWT_SECRET` (secret dédié **recette**, long et aléatoire)
- `FEDAPAY_SECRET_KEY` / `FEDAPAY_WEBHOOK_SECRET` (**sandbox** FedaPay)
- (Selon hébergeur) ajustement **forward headers** si HTTPS se termine à l’**ALB**

**Ne jamais** commiter de secrets : gestion par **paramètres** AWS / **Secrets Manager** / variables du service, pas dans Git.

---

## 7. Guide détaillé déjà dans le dépôt

- `infra/aws/README.md` : procédure longue, liens console, rappels SPA / CloudFront / FedaPay
- `infra/aws/dns-safaricloud.example.md` : tableau d’enregistrements DNS type
- `infra/aws/staging.env.example` : champs à noter (ARN, URLs) — le fichier `infra/aws/staging.env` local est en `.gitignore` si contient des brouillons sensibles
- `ROADMAP.md` : vision produit + lien vers l’infra AWS

---

## 8. Contraintes / pièges

- **CORS** : les **origines** listées côté Spring sont les **URL du front** (`https://int.mobili.ci`), **pas** l’URL de l’API.
- **Certificat CloudFront** : **obligatoirement** en **`us-east-1`**.
- **Domaine `mobili.com`** a été considéré **trop cher** (revente tiers sur OVH) : le choix retenu est **`.ci`**.
- Compte **AWS** : certains services (ex. enregistrement de domaine chez AWS) peuvent être refusés sur certains comptes ; le domaine est **chez Safaricloud**, donc **pas** bloquant.
- **Coût** : surveiller **RDS** et trafic ; rester en **recette** (pas de sur-dimensionnement).

---

## 9. Demande type pour l’assistant (Gemini)

Tu peux ajouter : *« Guide-moi dans la **console AWS** en respectant l’ordre de la section 5, une étape à la fois. Région Paris pour tout sauf ACM pour CloudFront en Virginie. Mon DNS est chez **Safaricloud** pour `mobili.ci`. Si une étape dépend d’un prérequis (domaine actif, certificat issued), dis-le clairement. »*

---

*Document interne — projet Mobili.*
