import { APP_INITIALIZER, ApplicationConfig, ErrorHandler, LOCALE_ID, provideBrowserGlobalErrorListeners } from '@angular/core';
import * as Sentry from '@sentry/angular';
import { provideRouter, withInMemoryScrolling } from '@angular/router';
import { provideHttpClient, withFetch, withInterceptors } from '@angular/common/http';
import { registerLocaleData } from '@angular/common';
import localeFr from '@angular/common/locales/fr';
import localeFrExtra from '@angular/common/locales/extra/fr';

import { firstValueFrom } from 'rxjs';

import { routes } from './app.routes';
import { apiInterceptor } from './core/interceptors/api.interceptor';
import { authInterceptor } from './core/interceptors/auth.interceptor';
import { AuthService } from './core/services/auth/auth.service';
import { MOBILI_APP_KIND, type MobiliAppKind } from './core/config/mobili-app-kind.token';
import { provideClientHydration, withEventReplay } from '@angular/platform-browser';

registerLocaleData(localeFr, 'fr', localeFrExtra);

export const appConfig: ApplicationConfig = {
  providers: [
    { provide: MOBILI_APP_KIND, useValue: 'passenger' satisfies MobiliAppKind },
    { provide: LOCALE_ID, useValue: 'fr' },
    {
      provide: APP_INITIALIZER,
      useFactory: (auth: AuthService) => () => firstValueFrom(auth.hydrateFromRefresh()),
      deps: [AuthService],
      multi: true,
    },
    // scrollPositionRestoration: 'top' — sans ça, une page ouverte via routerLink hérite du
    // scroll de la page précédente (feedback testeurs : CGU/Confidentialité s'ouvraient au
    // milieu/en bas de l'écran).
    provideRouter(
      routes,
      withInMemoryScrolling({ scrollPositionRestoration: 'top', anchorScrolling: 'enabled' }),
    ),
    provideBrowserGlobalErrorListeners(),
    // Error tracking (Sentry) — voir main.ts pour Sentry.init(), uniquement côté navigateur.
    // Sûr à fournir ici même si app.config.ts est partagé avec le SSR (app.config.server.ts) :
    // le SDK Sentry n'a jamais reçu d'appel `init()` côté serveur, donc `handleError` n'y fait
    // simplement rien (pas d'exception, pas d'appel réseau) au lieu de planter le rendu.
    { provide: ErrorHandler, useValue: Sentry.createErrorHandler() },

    provideHttpClient(
      // withFetch() : HttpClient utilise XMLHttpRequest par défaut, absent sous Node (SSR) —
      // requis pour tout appel HTTP fait pendant le rendu serveur.
      withFetch(),
      withInterceptors([
        apiInterceptor,
        authInterceptor,
      ]),
    ), provideClientHydration(withEventReplay()),
  ],
};
