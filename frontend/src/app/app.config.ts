import { ApplicationConfig, LOCALE_ID, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { registerLocaleData } from '@angular/common';
import localeFr from '@angular/common/locales/fr';
import localeFrExtra from '@angular/common/locales/extra/fr';

import { routes } from './app.routes';
import { apiInterceptor } from './core/interceptors/api.interceptor';
import { authInterceptor } from './core/interceptors/auth.interceptor';

registerLocaleData(localeFr, 'fr', localeFrExtra);

export const appConfig: ApplicationConfig = {
  providers: [
    { provide: LOCALE_ID, useValue: 'fr' },
    provideRouter(routes),
    provideBrowserGlobalErrorListeners(),

    provideHttpClient(
      withInterceptors([
        apiInterceptor,
        authInterceptor,
      ]),
    ),
  ],
};
