import { bootstrapApplication } from '@angular/platform-browser';
import * as Sentry from '@sentry/angular';
import { appConfig } from './app/app.config';
import { App } from '../src/app/app';
 // Vérifie que le fichier est bien src/app/app.ts

// Error tracking (voir docs/INFRA-OPS.md) — uniquement le monitoring d'erreurs pour l'instant, pas
// de tracing/session replay (consomment le quota gratuit séparément, pas activés tant qu'on n'en
// a pas besoin). Navigateur uniquement : jamais initialisé côté serveur (SSR, main.server.ts) —
// le SDK @sentry/angular cible le navigateur, pas Node.
Sentry.init({
  dsn: 'https://29cfad0bc05516d0e3c85035a6643e22@o4512063188303872.ingest.de.sentry.io/4512063210651728',
});

bootstrapApplication(App, appConfig).catch((err) => console.error(err));
