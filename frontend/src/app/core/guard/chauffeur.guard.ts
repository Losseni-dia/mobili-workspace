import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth/auth.service';

/** Accès aux outils de test des API chauffeur (rôles partenaire / admin / chauffeur). */
export const chauffeurGuard: CanActivateFn = (_route, state) => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (!auth.isLoggedIn()) {
    return router.createUrlTree(['/auth/login'], { queryParams: { returnUrl: state.url } });
  }
  if (auth.currentUser()?.covoiturageSoloProfile) {
    return router.createUrlTree(['/covoiturage/piloter']);
  }
  if (
    auth.hasRole('CHAUFFEUR') ||
    auth.hasRole('PARTNER') ||
    auth.hasRole('GARE') ||
    auth.hasRole('ADMIN')
  ) {
    return true;
  }
  return router.createUrlTree(['/']);
};
