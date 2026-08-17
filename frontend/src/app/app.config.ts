import { APP_INITIALIZER, ApplicationConfig, LOCALE_ID, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter, withInMemoryScrolling } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { registerLocaleData } from '@angular/common';
import localeFr from '@angular/common/locales/fr';
import localeFrExtra from '@angular/common/locales/extra/fr';

import { firstValueFrom } from 'rxjs';

import { routes } from './app.routes';
import { apiInterceptor } from './core/interceptors/api.interceptor';
import { authInterceptor } from './core/interceptors/auth.interceptor';
import { AuthService } from './core/services/auth/auth.service';
import { MOBILI_APP_KIND, type MobiliAppKind } from './core/config/mobili-app-kind.token';

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

    provideHttpClient(
      withInterceptors([
        apiInterceptor,
        authInterceptor,
      ]),
    ),
  ],
};
