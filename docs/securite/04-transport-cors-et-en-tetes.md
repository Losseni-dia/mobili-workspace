# Sécurité — Transport, CORS & en-têtes HTTP

 [← Index sécurité](README.md)

## Synthèse

La surface réseau (origines autorisées, en-têtes de réponse) doit être **alignée sur chaque environnement** (local, staging, production, apps natives).

## Sous-thèmes

### CORS

- Configuration : [`MobiliCorsSettings`](../../backend/mobili-boot/src/main/java/com/mobili/backend/infrastructure/configuration/MobiliCorsSettings.java) / branchement dans `SecurityConfig`.
- **Production** : lister explicitement les domaines front **et** les besoins **Capacitor** / WebView si applicable — éviter `*` avec credentials.

### CSRF

- Désactivé pour une API **JWT** classique : pas de cookie de session pour les actes métier.
- Le cookie **refresh** doit rester cantonné au flux prévu ; pas d’actions sensibles « session cookie only » sans contre-mesure équivalente.

### En-têtes de sécurité (Spring Security)

- Configurés dans `SecurityConfig` (ex. frame options deny, `X-Content-Type-Options`, `Referrer-Policy`).
- À compléter au besoin (CSP, HSTS au niveau reverse proxy) selon l’hébergement.

### HTTPS

- Obligatoire en production pour JWT, cookies et protection des données personnelles.
