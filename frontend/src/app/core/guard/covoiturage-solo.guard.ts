import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth/auth.service';

/** Espace covoiturage « grand public » (inscription BlaBla) : profil dédié, distinct partenaire / gare. */
export const covoiturageSoloGuard: CanActivateFn = (_route, state) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (!auth.isLoggedIn()) {
    return router.createUrlTree(['/auth/login'], { queryParams: { returnUrl: state.url } });
  }
  if (auth.hasRole('ADMIN') || auth.currentUser()?.covoiturageSoloProfile === true) {
    return true;
  }
  return router.createUrlTree(['/']);
};
