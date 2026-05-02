import { APP_INITIALIZER, ApplicationConfig, LOCALE_ID, provideBrowserGlobalErrorListeners } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { registerLocaleData } from '@angular/common';
import localeFr from '@angular/common/locales/fr';
import localeFrExtra from '@angular/common/locales/extra/fr';

import { businessRoutes } from './business.routes';
import { apiInterceptor } from '@mobili-app/core/interceptors/api.interceptor';
import { authInterceptor } from '@mobili-app/core/interceptors/auth.interceptor';
import { AuthService } from '@mobili-app/core/services/auth/auth.service';
import { MOBILI_APP_KIND, type MobiliAppKind } from '@mobili-app/core/config/mobili-app-kind.token';

registerLocaleData(localeFr, 'fr', localeFrExtra);

export const appConfig: ApplicationConfig = {
  providers: [
    { provide: MOBILI_APP_KIND, useValue: 'business' satisfies MobiliAppKind },
    { provide: LOCALE_ID, useValue: 'fr' },
    {
      provide: APP_INITIALIZER,
      useFactory: (auth: AuthService) => () => firstValueFrom(auth.hydrateFromRefresh()),
      deps: [AuthService],
      multi: true,
    },
    provideRouter(businessRoutes),
    provideBrowserGlobalErrorListeners(),
    provideHttpClient(
      withInterceptors([apiInterceptor, authInterceptor]),
    ),
  ],
};
