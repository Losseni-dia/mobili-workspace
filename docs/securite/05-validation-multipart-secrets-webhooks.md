# Sécurité — Validation entrées, multipart, secrets & webhooks

 [← Index sécurité](README.md)

## Synthèse

Réduction de la surface d’abus : limites de taille des requêtes multipart, validation **réelle** des fichiers (magic bytes), secrets hors dépôt, webhooks authentifiés.

## Sous-thèmes

### Multipart (Spring)

- `spring.servlet.multipart.max-file-size` / `max-request-size` dans [`application.yml`](../../backend/mobili-boot/src/main/resources/application.yml).

### Images uploadées

- Taille max : `mobili.backend.upload.max-bytes-per-file`.
- Types autorisés : JPEG, PNG, WebP — contrôle MIME **et** signature fichier dans `UploadService`.

### PDF

- Taille max : `mobili.backend.upload.max-bytes-per-document`.
- Validation en-tête `%PDF` dans `UploadService.saveDocument`.

### Secrets & configuration

- JWT, clés paiement, mots de passe base : **variables d’environnement** / gestionnaire de secrets — jamais dans Git (`.env` ignoré).

### Webhook paiement

- Vérification de signature / secret partagé (ex. FedaPay) avant traitement métier — ne pas faire confiance au seul corps HTTP.

### Actuator (production)

- Limiter l’exposition (ex. health « liveness » sans détails sensibles) — voir profils `application-prod.yml` / staging.
