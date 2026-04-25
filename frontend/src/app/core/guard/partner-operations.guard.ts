import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { map, of, switchMap } from 'rxjs';
import { AuthService } from '../services/auth/auth.service';
import { isStationReadyForTrips, PartenaireService } from '../services/partners/partenaire.service';

/**
 * Même règles que la sidebar partenaire : gare (rôle) non validée → accueil gare ;
 * dirigeant sans aucune gare prête → page Gares.
 */
export const partnerOperationsGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const partenaire = inject(PartenaireService);
  const router = inject(Router);

  return auth.fetchUserProfile().pipe(
    switchMap((u) => {
      if (auth.hasRole('GARE') && u.gareOperationsEnabled === false) {
        return of(router.createUrlTree(['/gare/accueil']));
      }
      if (auth.hasRole('PARTNER') && !auth.hasRole('GARE')) {
        return partenaire.listStations().pipe(
          map((list) => {
            if (list.length === 0 || !list.some((s) => isStationReadyForTrips(s))) {
              return router.createUrlTree(['/partenaire/gares'], { queryParams: { needValidation: '1' } });
            }
            return true;
          }),
        );
      }
      return of(true);
    }),
  );
};
