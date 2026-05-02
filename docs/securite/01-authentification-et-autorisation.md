# Sécurité — Authentification & autorisation

 [← Index sécurité](README.md)

## Synthèse

L’API est **stateless** : session HTTP désactivée, identification via **JWT** (Bearer) sur les routes protégées. Un **cookie httpOnly** sert au flux refresh selon la configuration (`SecurityConfig`, filtres JWT).

## Sous-thèmes

### JWT & Principal

- Filtre : `JwtAuthenticationFilter` (chaîne Spring Security).
- Identité applicative : `UserPrincipal` (utilisateur + contexte partenaire / gare dérivé au chargement).
- Les contrôleurs sensibles doivent prendre l’**identité** depuis le `Principal`, pas depuis un champ « userId » arbitraire du corps JSON (ex. réservations).

### Rôles

- Rôles métier : `USER`, `PARTNER`, `GARE`, `CHAUFFEUR`, `ADMIN` (enum `UserRole`, préfixe Spring `ROLE_*`).
- Règles fines par préfixe : [`SecurityConfig`](../../backend/mobili-boot/src/main/java/com/mobili/backend/infrastructure/security/SecurityConfig.java) + constantes [`MobiliApiPaths`](../../backend/mobili-core/src/main/java/com/mobili/backend/infrastructure/security/MobiliApiPaths.java).

### Cookie refresh

- Nom et durée : `mobili.security.jwt.refresh` dans `application.yml`.
- En production : activer **`Secure`** sur HTTPS et ajuster **`SameSite`** selon la stratégie cross-sous-domaine (voir [checklist QA](../RELEASE-QA-MOBILI.md)).

### Méthode sécurisée (`@PreAuthorize`)

- Complément possible aux `requestMatchers` pour des règles très locales ; le périmètre nominal reste centralisé dans `SecurityConfig` pour lisibilité.
