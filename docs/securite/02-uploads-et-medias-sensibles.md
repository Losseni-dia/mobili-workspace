# Sécurité — Fichiers, uploads & médias sensibles

 [← Index sécurité](README.md)

## Synthèse

Les fichiers utilisateur ne sont **pas** tous exposés de la même façon : une partie reste **statique publique** (avatars, logos, photos trajets « catalogue »), une partie **sensible** (KYC covoiturage, dossier documents configuré) est servie **uniquement** via une API authentifiée.

## Sous-thèmes

### Stockage disque

- Racine : `mobili.backend.upload.root-directory` (souvent `uploads/`).
- Écriture : [`UploadService`](../../backend/mobili-boot/src/main/java/com/mobili/backend/shared/sharedService/UploadService.java) (`saveImage`, `saveDocument` pour PDF).

### Statique HTTP public (Spring MVC)

- Configuration : [`WebConfig`](../../backend/mobili-boot/src/main/java/com/mobili/backend/infrastructure/configuration/WebConfig.java).
- Préfixes **autorisés** en lecture anonyme :
  - `/uploads/users/**`
  - `/uploads/partners/**`
  - `/uploads/vehicles/**`
- **Non exposés** en statique : chemins `sensitive/**`, anciens préfixes KYC `covoiturage-ids|drivers|vehicles/**`, dossier `documents-folder` (YAML), etc.

### Sécurité Spring (`permitAll`)

- Alignée sur les **mêmes** préfixes que la config MVC (`SecurityConfig`), pour éviter qu’un fichier soit servi par le handler mais bloqué par erreur (ou l’inverse).

### Médias sensibles — API privée

- Endpoint : **`GET /v1/media/private?rel=…`** (`PrivateMediaController`, [`PrivateMediaService`](../../backend/mobili-boot/src/main/java/com/mobili/backend/shared/sharedService/PrivateMediaService.java)).
- **Authentification obligatoire** ; pas de fuite par URL `/uploads/…` directe pour ces chemins.
- Contrôle d’accès typique :
  - **`ROLE_ADMIN`** : lecture des fichiers existants sous les préfixes sensibles concernés.
  - **Utilisateur** : uniquement si `rel` correspond à une des URLs KYC stockées sur **son** compte (recto/verso pièce, photo conducteur, photo véhicule déclarée).
- Normalisation stricte du chemin (pas de `..`).
- En-tête **`Cache-Control: no-store`** sur la réponse.

### KYC covoiturage (création compte)

- Dossiers recommandés : constantes `FOLDER_SENSITIVE_COVOITURAGE_*` dans `UploadService` (`sensitive/covoiturage/ids|drivers|vehicles`).
- Pièce d’identité : **image** ou **PDF** (recto/verso), toujours sous le dossier IDs sensible.

### PDF & dossier `documents`

- Dossier configurable : `mobili.backend.upload.documents-folder` ( défaut `documents`).
- Trait comme préfixe **sensible** pour `/v1/media/private` ; hors statique public.
- Accès utilisateur standard : réservé aux chemins effectivement référencés sur le profil (sinon **admin** pour le reste du dossier documents).

### Frontend

- Détection des chemins sensibles : `ConfigurationService.isSensitiveUploadRelativePath`.
- Affichage : composant `mobili-secure-upload-img` (blob + JWT ; lien PDF si besoin).
- Variable optionnelle **`uploadDocumentsFolder`** côté front pour suivre un YAML qui ne serait plus `documents`.

### Évolution partenaire (KBIS, etc.)

- Constante prévue : `UploadService.FOLDER_SENSITIVE_PARTNER_LEGAL` — à relier à une colonne URL sur `Partner` et aux mêmes principes d’accès (propriétaire + admin).
