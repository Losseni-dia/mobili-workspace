import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { map } from 'rxjs';
import { AuthService } from '../services/auth/auth.service';

/**
 * Blocage des routes gare (hors accueil) si la gare n’est pas encore validée
 * côté compagnie ou si le profil n’a pas les droits d’exploitation.
 */
export const gareOperationsGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (!auth.hasRole('GARE')) {
    return true;
  }

  const u = auth.currentUser();
  if (u && 'gareOperationsEnabled' in u && u.gareOperationsEnabled === false) {
    return router.createUrlTree(['/gare/accueil']);
  }
  if (u && 'gareOperationsEnabled' in u && u.gareOperationsEnabled === true) {
    return true;
  }

  return auth.fetchUserProfile().pipe(
    map((full) =>
      full.gareOperationsEnabled === false ? router.createUrlTree(['/gare/accueil']) : true,
    ),
  );
};
