import { inject } from '@angular/core';
import { Router, CanActivateFn } from '@angular/router';
import { AuthService } from '../../core/services/auth/auth.service';

/**
 * AUDIT-MOBILI.md §2.1 : `/gare` n'était protégée que par authGuard (= "connecté"),
 * pas par un contrôle de rôle — un simple voyageur (rôle USER) tapant /gare/tickets
 * passait ce guard et voyait le shell se charger. Même modèle strict que adminGuard.
 */
export const gareRoleGuard: CanActivateFn = () => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (authService.hasRole('GARE')) {
    return true;
  }

  router.navigate(['/']);
  return false;
};
