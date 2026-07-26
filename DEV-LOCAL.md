## token pour test
```bash
TOKEN=$(MSYS_NO_PATHCONV=1 curl -s -X POST http://localhost:8080/v1/auth/login -H "Content-Type: application/json" -d '{"login":"dia","password":"123456"}' | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"$//')
````


# 🚀 Guide de Déploiement Mobili
## Ordre d'exécution

---
## 0. Dans Vscode
```bash
mvn clean install 
```

## 1. Build Backend (Spring Boot)
```bash


cd C:\Users\User\Desktop\prj\mobili\backend\mobili-boot
mvn clean package -DskipTests
scp -i C:\Users\User\Downloads\mobili-key.pem target\application.jar ec2-user@51.45.30.213:/home/ec2-user/

ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo systemctl restart mobili"

ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo systemctl status mobili"

curl https://api.my-mobili.com/v1/actuator/health


## Outil de monitoring : uptimerobot

https://dashboard.uptimerobot.com/monitors/803590903


```

---

## 2. Déploiement Backend sur EC2
```bash
scp -i C:\Users\User\Downloads\mobili-key.pem target\application.jar ec2-user@51.45.30.213:/home/ec2-user/
```

---

## 3. Redémarrage du service sur EC2
```bash
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo systemctl restart mobili"
```

---

## 4. Vérification du service
```bash
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo systemctl status mobili"
```

---

## 5. Vérification santé de l'API
```bash
curl https://api.my-mobili.com/v1/actuator/health
```
Réponse attendue : `{"status":"UP"}`

---

## 6. Build APK Mobili (App Passager)
```bash
cd ~/Desktop/prj/mobili/mobile_app
flutter build apk --release
```
APK généré : `build\app\outputs\flutter-apk\app-release.apk`

---

## 7a. Voir les logs en temps réel
```bash
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo journalctl -u mobili -f"
```

## 7b. Voir les anciens logs :emps réel
```bash
# Dernières 100 lignes
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo journalctl -u mobili -n 100"

# Logs d'aujourd'hui
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo journalctl -u mobili --since today"

# Logs avec erreurs uniquement
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo journalctl -u mobili -p err"

# Logs avec erreurs sur interval
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo journalctl -u mobili --since '2026-07-21 13:09:30' --until '2026-07-21 13:09:40'"

```

---

## 8. Build APK MobiliPro (App Professionnelle)
```bash
cd ~/Desktop/prj/mobili/mobilipro
flutter build apk --release
```
APK généré : `build\app\outputs\flutter-apk\app-release.apk`

---

## 9. Installation sur téléphone via USB
```bash
# Lister les appareils connectés
flutter devices

# Installer Mobili
cd ~/Desktop/prj/mobili/mobile_app
flutter run --release -d 9d54e590

# Installer MobiliPro
cd ~/Desktop/prj/mobili/mobilipro
flutter run --release -d 9d54e590
```

---

## 10. Logs Backend en temps réel (debug)
```bash
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213 "sudo journalctl -u mobili -f"
```

---

## Informations de connexion EC2
| Paramètre | Valeur |
|---|---|
| IP Elastic | 51.45.30.213 |
| Clé SSH | C:\Users\User\Downloads\mobili-key.pem |
| Utilisateur | ec2-user |
| API URL | https://api.my-mobili.com/v1 |
| Health Check | https://api.my-mobili.com/v1/actuator/health |



# Connexion à la base de données Mobili (RDS)

## Infos de connexion

| Paramètre | Valeur |
|---|---|
| Endpoint RDS | `mobili-db-staging.cng2w8wes1qt.eu-west-3.rds.amazonaws.com` |
| Port | `5432` |
| Base de données | `mobili_db` |
| Utilisateur | `postgres` |
| Mot de passe | *(le tien, non stocké ici)* |

## Connexion dans powershell
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213
psql -h mobili-db-staging.cng2w8wes1qt.eu-west-3.rds.amazonaws.com -U postgres -d mobili_db
Mot de pass

## Pourquoi on ne peut pas se connecter directement depuis son PC

La base RDS n'autorise que les connexions provenant du serveur EC2 (`mobili-server`,
IP `51.45.30.213`) — via le security group `default (sg-0c9c6296998653053)`, qui
whitelist les security groups de l'instance EC2, pas les IP personnelles.

Donc pour interroger la base, il faut passer **par le serveur EC2** en SSH, pas
directement depuis son PC (sauf si on ouvre explicitement l'accès à son IP dans
le security group RDS — non fait ici).

## Étapes complètes

### 1. Se connecter en SSH au serveur EC2

Depuis PowerShell, avec la clé `.pem` :

```powershell
ssh -i C:\Users\User\Downloads\mobili-key.pem ec2-user@51.45.30.213
```

### 2. Depuis le serveur EC2, se connecter à la base PostgreSQL

```bash
psql -h mobili-db-staging.cng2w8wes1qt.eu-west-3.rds.amazonaws.com -U postgres -d mobili_db
```

→ demande le mot de passe RDS.

### 3. Commandes psql utiles une fois connecté

```sql
-- Lister toutes les bases
\l

-- Lister toutes les tables de la base courante
\dt

-- Voir la structure d'une table
\d nom_table

-- Quitter psql
\q
```

### 4. Exemple de requête utilisée (debug photos covoiturage)

```sql
SELECT covoiturage_driver_photo_url, covoiturage_vehicle_photo_url
FROM users
WHERE covoiturage_driver_photo_url IS NOT NULL
LIMIT 5;
```


## Infra de référence (rappel)

| Composant | Valeur |
|---|---|
| Région AWS | eu-west-3 (Paris) |
| EC2 Instance | `i-0ae94f8feecac137c` — mobili-server |
| IP Elastic (fixe) | `51.45.30.213` |
| RDS Instance | `mobili-db-staging` |
| API prod | `https://api.my-mobili.com/v1` |








# Démarrage des émulatteurs flutter
flutter run -d emulator-5554 PIXEL_8
flutter run -d emulator-5556   PIXEL_4

reboost : cd ~/AppData/Local/Android/Sdk/emulator
./emulator -avd Pixel_8 -no-snapshot-load -gpu swiftshader_indirect


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
JWT_SECRET=<générer avec: openssl rand -base64 32>
FEDAPAY_SECRET_KEY=<clé sandbox depuis dashboard.fedapay.com>
FEDAPAY_WEBHOOK_SECRET=<secret webhook depuis dashboard.fedapay.com>
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
