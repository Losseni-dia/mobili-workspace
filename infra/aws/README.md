# AWS — recette `int.mobili.ci` + `api.int.mobili.ci`

Guide **hors exécution automatique** : à suivre dans la [console AWS](https://console.aws.amazon.com/) quand le domaine **`mobili.ci`** est **actif** et la **zone DNS** gérable (ex. [Safaricloud](https://safaricloud.net/)).

**Région par défaut** (API, RDS, ALB, certificat API) : **`eu-west-3` (Paris)**.  
**Certificat CloudFront** : obligatoirement **`us-east-1` (N. Virginia)** — c’est imposé par AWS pour CloudFront.

---

## 1. Prérequis côté toi

- [ ] Compte AWS + facturation (carte)
- [ ] `mobili.ci` **actif** + accès **DNS** (CNAME) chez le registrar
- [ ] Cible pour l’**API** choisie : **ECS Fargate + ALB** (recommandé staging) *ou* **Elastic Beanstalk** (Java) *ou* **EC2** (plus manuel). Ce guide note surtout **ALB** pour l’exemple `api.int`.

---

## 2. Certificat SSL — front (CloudFront)

1. Région **`us-east-1`** (sélecteur en haut à droite de la console).
2. Ouvre **Certificate Manager (ACM)** :  
   <https://us-east-1.console.aws.amazon.com/acm/home?region=us-east-1>
3. **Request** → **Public certificate** → noms :  
   `int.mobili.ci` et (option) `www.int.mobili.ci`
4. **Validation DNS** : ajoute le(s) **CNAME** indiqué(s) par ACM dans la **zone `mobili.ci`** (Safaricloud → DNS), puis **attends** le statut **Issued**.

---

## 3. Certificat SSL — API (ALB)

1. Région **`eu-west-3`**.
2. **ACM** :  
   <https://eu-west-3.console.aws.amazon.com/acm/home?region=eu-west-3>
3. Même principe : certificat pour **`api.int.mobili.ci`**, validation **DNS** (CNAME chez Safaricloud).
4. Note l’**ARN** du certificat (pour l’ALB, étape 7).

---

## 4. Front Angular — S3 + CloudFront

1. **S3** : crée un **bucket** (nom **globalement unique**, ex. `mobili-staging-int-TONIDCOMPTE-euwest3`) — **pas** d’accès public direct ; l’accès se fera par **CloudFront (OAC)**.
2. **CloudFront** :  
   <https://console.aws.amazon.com/cloudfront/v4/home>
3. **Create distribution** : origine = bucket S3 (l’assistant propose **OAC** / origine type S3).  
4. **Alternate domain (CNAME)** : `int.mobili.ci` (+ `www` si certificat).  
5. **Custom SSL** : le certificat **ACM** créé en **us-east-1** (étape 2).  
6. **Default root object** : `index.html`.  
7. **Erreurs SPA (Angular)** : onglet **Error pages** (ou *Custom error response*) : pour **403** et **404**, réponse **200** vers **`/index.html`** (comportement classique d’une SPA).  
8. **Build** en local : `ng build --configuration=production` puis uploader le contenu de **`dist/.../browser`** dans le bucket (ou pipeline CI).  
9. **Invalidation** CloudFront : après chaque déploiement, invalider `/*` (ou scripté).

Récupère le **domaine** CloudFront (ex. `d111111abcdef8.cloudfront.net`).

---

## 5. DNS — enregistrements chez Safaricloud (zone `mobili.ci`)

Quand **CloudFront** et l’**ALB** (ou la cible API) existent, crée notamment :

| Type | Sous-domaine / nom | Cible (exemple) |
|------|--------------------|-----------------|
| **CNAME** | `int` | `dxxxx.cloudfront.net` (domaine de la distribution) |
| **CNAME** | `www.int` | idem, si tu utilises le `www` |
| **CNAME** | `api.int` | `xxx-123456789.eu-west-3.elb.amazonaws.com` (nom DNS de l’**ALB**) |

*(Si l’UI propose le **FQDN** complet : `int.mobili.ci` → c’est le même enregistrement `int` dans la zone `mobili.ci`.)*

Propagation : de **quelques minutes** à **24–48 h**.

Fichier d’aide : [`dns-safaricloud.example.md`](dns-safaricloud.example.md) (même contenu, prêt à remplir).

---

## 6. Base de données — RDS PostgreSQL (recette)

1. **RDS** en **`eu-west-3`** :  
   <https://eu-west-3.console.aws.amazon.com/rds/home?region=eu-west-3#databases:>
2. Moteur **PostgreSQL**, **non** en accès public si possible (VPC + security group, même réseau que l’**ECS/Beanstalk/EC2**).  
3. Récupère l’**endpoint** pour `DB_URL` (ex. `jdbc:postgresql://mon-rds.xxx.eu-west-3.rds.amazonaws.com:5432/mobili_staging`).

---

## 7. API Spring Boot

**Option A — ECS Fargate** : image `backend/Dockerfile` → **ECR** → service **Fargate** derrière un **ALB** (port **443** + certificat `api.int.mobili.ci`).

Modèle de **Task Definition** (secrets `DB_*`, JWT, FedaPay, profil **via SSM** Parameter Store, ports **8080**, `executionRoleArn` à adapter) : [`ecs/task-definition.json`](ecs/task-definition.json). Rôle d’**exécution** (pull ECR, logs, **lecture SSM** sur `parameter/mobili/staging/*`) : voir [IAM pour ECS + SSM](ecs/IAM-ECR-SSM.md).

**Option B — Elastic Beanstalk** (Java) : déploiement JAR, variables d’environnement, ALB géré.

Variables **minimales** (même logique que `backend/.env`, mais **côté task / Beanstalk**) :

- `SPRING_PROFILES_ACTIVE=staging`
- `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`
- `JWT_SECRET`, `FEDAPAY_SECRET_KEY`, `FEDAPAY_WEBHOOK_SECRET` (sandbox)
- (Option) `server.forward-headers-strategy=framework` si **HTTPS** se termine à l’ALB — à valider selon l’hébergeur.

L’URL publique d’**entrée** doit être **`https://api.int.mobili.ci`**.

**FedaPay (sandbox)** : URL de callback =  
`https://api.int.mobili.ci/v1/payments/callback`  
(à enregistrer côté dashboard FedaPay quand l’URL répond en HTTPS).

---

## 8. Cohérence avec le code du dépôt

- CORS : [`application-staging.yml`](../../backend/src/main/resources/application-staging.yml) (origines `https://int.mobili.ci`, etc.).
- Front : [`app.env.config.ts`](../../frontend/src/app/app.env.config.ts) (`api.int.mobili.ci/v1`).

---

## 9. CD GitHub — ECR + ECS (activé)

Le workflow [`.github/workflows/cd.yml`](../../.github/workflows/cd.yml) se déclenche sur **push** vers **`main`** ou **manuellement** (*Actions* → *CD* → *Run workflow*).

- **Build** l’image `backend/Dockerfile`, **tag** `:${{ github.sha }}` + `:latest`, **push** vers ECR `mobili-backend-staging` (`eu-west-3`).  
- **ECS** : si les **variables** du dépôt `ECS_CLUSTER` et `ECS_SERVICE` sont renseignées (*Settings* → *Secrets and variables* → *Actions* → *Variables*), exécute `update-service` avec `--force-new-deployment` pour prendre la nouvelle image. Sinon, seul le push ECR est fait (avertissement dans les logs).  
- **Secrets** requis : `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (compte / utilisateur IAM avec droits ECR push + `ecs:UpdateService` sur le cluster cible).  
- **OIDC** (recommandé à terme) : [doc GitHub – AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services).

---

## 10. Coût & prudence

- Surveille la **facturation** (Free Tier partiel, RDS = souvent le poste le plus visible).  
- **Staging** : mets des **gardiens** (sécurité des groupes, **pas** de clé AWS en clair dans le dépôt).

---

*Dernière mise à jour : doc interne recette, à ajuster selon l’option exacte (Beanstalk / ECS) que tu retiens.*
