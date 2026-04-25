import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth/auth.service';

export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  // On vérifie si l'utilisateur est connecté via notre Signal
  if (authService.isLoggedIn()) {
    return true; // Accès autorisé
  }

  // Sinon, on redirige vers le login avec l'URL de retour en mémoire
  console.warn('Accès refusé : redirection vers la connexion');
  return router.createUrlTree(['/auth/login'], {
    queryParams: { returnUrl: state.url },
  });
};
