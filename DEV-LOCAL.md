# Démarrage en local

## Prérequis

| Outil | Version minimale |
|---|---|
| Java (JDK) | 21 |
| Maven | 3.9+ (ou utiliser `mvnw`) |
| Node.js | 18+ |
| npm | 10+ |
| PostgreSQL | 14+ |

---

## 1. Base de données

PostgreSQL doit tourner localement sur le port **5432** avec :

| Paramètre | Valeur |
|---|---|
| Base | `mobili_db` |
| Utilisateur | `postgres` |
| Mot de passe | `root` |

Créer la base si elle n'existe pas :

```sql
CREATE DATABASE mobili_db;
```

> Flyway applique les migrations automatiquement au démarrage du backend.

---

## 2. Backend (Spring Boot)

### Variables d'environnement

Le backend lit ses variables depuis `backend/.env`. Avant le premier lancement, vérifier que ce fichier existe avec les bonnes valeurs :

```env
SPRING_PROFILES_ACTIVE=dev
DB_URL=jdbc:postgresql://localhost:5432/mobili_db
DB_USERNAME=postgres
DB_PASSWORD=root
JWT_SECRET=8XrFlAxnLp1AWIDQEjVoLLxKshCF96Di8iGR8VluLVw=
FEDAPAY_SECRET_KEY=sk_sandbox_FnpLiL2_76PO2bm1rrjC2Y2L
FEDAPAY_WEBHOOK_SECRET=lodi_maya_nana_mobili_2050
```

> Spring ne charge pas `.env` automatiquement. Les variables doivent être exportées dans le terminal ou configurées dans l'IDE (Run Configuration → Environment variables).

### Lancement

```powershell
cd backend

# Avec le wrapper Maven (recommandé)
.\mvnw.cmd spring-boot:run -pl mobili-boot

# Ou depuis l'IDE : lancer BackendApplication.java avec le profil "dev"
```

Le backend démarre sur **http://localhost:8080**

### Vérification

```powershell
curl http://localhost:8080/actuator/health
# Attendu : {"status":"UP"}
```

---

## 3. Frontend

```powershell
cd frontend

# Installer les dépendances (une seule fois)
npm install
```

### Interface User (passagers)

```powershell
npm start
```

Accessible sur **http://localhost:4200**

### Interface Business (partenaires / admin)

```powershell
npm run start:business
```

Accessible sur **http://localhost:4200** (port différent si conflit)

> Les deux interfaces proxifient automatiquement les appels `/v1/*` et `/uploads/*` vers `http://localhost:8080`. Le backend doit donc être démarré pour que les API fonctionnent.

---

## Ordre de démarrage recommandé

```
1. PostgreSQL  →  déjà en cours d'exécution
2. Backend     →  mvnw spring-boot:run
3. Frontend    →  npm start  ou  npm run start:business
```
