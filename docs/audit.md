# Audit complet — Projet Mobili
**Date :** 2026-05-07  
**Auditeur :** Claude Code (Anthropic)  
**Branche :** Feature_Testing_Sonar_scan

---

## Vue d'ensemble

**Type :** Monorepo Angular 21 multi-workspace

| Application | Description | Port |
|-------------|-------------|------|
| `frontend` | App passager | 4200 |
| `mobili-business` | App partenaire/station | 4201 |
| `mobili-shared` | Bibliothèque partagée | — |
| `backend` | Spring Boot Java | 8080 |

**Stack technique :**
- Angular 21.1.x
- TypeScript 5.9.2 (strict mode activé)
- RxJS 7.8.x
- TailwindCSS 4.2.1
- Docker / Docker Compose
- JWT + cookies HttpOnly pour l'authentification

---

## Points positifs

- Angular Signals utilisé correctement pour l'état réactif
- Composants standalone + lazy loading des routes
- Intercepteurs HTTP centralisés (API + Auth)
- Guards basés sur les rôles (auth, admin, chauffeur, partenaire)
- TypeScript strict mode activé
- Refresh token en cookie HttpOnly (bonne pratique)
- Gestion correcte des URLs sensibles (KYC via endpoint privé + JWT)
- `revokeObjectURL()` appelé correctement dans le composant upload

---

## Problèmes identifiés

### CRITIQUE

| # | Problème | Fichier | Détail |
|---|----------|---------|--------|
| 1 | **JWT stocké dans localStorage** | `frontend/src/app/core/services/auth/auth.service.ts:109` | Exposé à toute attaque XSS — le token d'accès peut être volé |
| 2 | **Aucune validation du fichier uploadé** | `frontend/src/app/shared/upload/mobili-secure-upload-img.component.ts:110-117` | La nouvelle méthode `uploadAvatar()` n'a aucun contrôle de type MIME, taille ou extension |
| 3 | **Configs multi-env supprimées** | `frontend/projects/mobili-shared/src/lib/mobili-env.config.ts` | Les environnements dev/staging/prod ont été retirés — impossible de déployer sans recompiler le code |

### HAUTE

| # | Problème | Fichier | Détail |
|---|----------|---------|--------|
| 4 | **Subscription non gérée dans logout()** | `frontend/src/app/core/services/auth/auth.service.ts:188` | `.subscribe()` sans `takeUntilDestroyed` → fuite mémoire + échec silencieux |
| 5 | **Mot de passe : minLength(6) insuffisant** | `frontend/src/app/features/auth/register-carpool-chauffeur/register-carpool-chauffeur.component.ts:32` | Aucune règle de complexité (majuscules, chiffres, caractères spéciaux) |
| 6 | **Fichiers KYC sans validation côté client** | `frontend/src/app/features/auth/register-carpool-chauffeur/register-carpool-chauffeur.component.ts:41-59` | Les pièces d'identité et photos sont uploadées sans aucun contrôle |

### MOYENNE

| # | Problème | Fichier | Détail |
|---|----------|---------|--------|
| 7 | **Interface `AuthResponse` dupliquée** | `frontend/src/app/core/interceptors/auth.interceptor.ts:9-18` | Définie aussi dans auth.service.ts avec des noms de propriétés différents (`avatar` vs `avatarUrl`) |
| 8 | **console.log sur les valeurs de config** | `frontend/src/app/configurations/services/configuration.service.ts:26,29` | Exposition d'informations d'environnement dans la console navigateur |
| 9 | **`JSON.parse` sans validation de structure** | `frontend/src/app/core/services/auth/auth.service.ts:218` | `as AuthResponse` est un cast sans vérification — un objet malformé peut provoquer des erreurs runtime |
| 10 | **Interpolation directe d'URL** | `frontend/src/app/core/services/auth/auth.service.ts:285` | Mieux d'utiliser `HttpParams` à la place de la concaténation de chaînes |
| 11 | **Aucun retour utilisateur sur accès refusé** | `frontend/src/app/core/guard/admin.guard.ts` | Redirection silencieuse — l'utilisateur ne sait pas pourquoi il a été bloqué |

### BASSE

| # | Problème | Détail |
|---|----------|--------|
| 12 | **Types `any` dans ~12 fichiers** | Contredit le mode strict activé dans tsconfig |
| 13 | **Route catch-all `**` sans page 404** | Toutes les URL inconnues redirigent vers `''` sans page d'erreur explicite |
| 14 | **Dockerfile sans utilisateur non-root** | Le conteneur tourne probablement en root |
| 15 | **Pas de healthcheck Docker** | Aucun `HEALTHCHECK` dans le Dockerfile |

---

## Analyse des fichiers modifiés (branche courante)

### 1. `mobili-env.config.ts`
**Changement :** Suppression de tous les environnements non-locaux (dev, acc, staging, prod)  
**Impact :** CRITIQUE — Déploiement multi-environnement cassé, viole le principe 12-factor app #3

### 2. `app.routes.ts`
**Changement :** Formatage uniquement (sauts de ligne)  
**Impact :** Aucun

### 3. `configuration.service.ts`
**Changement :** Espaces en fin de fichier  
**Impact :** Aucun

### 4. `mobili-secure-upload-img.component.ts`
**Changement :** Reformatage du template + **nouvelle méthode `uploadAvatar()`**

```typescript
// Nouveau code ajouté — RISQUE ÉLEVÉ
uploadAvatar(file: File) {
  const apiUrl = this.config.getEnvironmentVariable('apiUrl');
  const formData = new FormData();
  formData.append('file', file);
  return this.http.post(`${apiUrl}/images/upload-avatar`, formData);
}
```

**Problèmes :**
- Aucune validation du type MIME
- Aucune limite de taille
- Aucune gestion d'erreur
- Aucun suivi de progression

---

## Priorités de correction recommandées

1. Valider tous les uploads (type MIME, taille max, extension whitelist)
2. Restaurer la gestion multi-environnements avant tout déploiement
3. Déplacer le JWT en mémoire (ou passer full httpOnly)
4. Renforcer les règles de mot de passe (min 8 chars + complexité)
5. Consolider `AuthResponse` en une seule interface
6. Gérer les subscriptions avec `takeUntilDestroyed`
7. Supprimer les `console.log` avant la mise en production
