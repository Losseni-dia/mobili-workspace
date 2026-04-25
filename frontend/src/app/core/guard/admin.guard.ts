import { inject } from '@angular/core';
import { Router, CanActivateFn } from '@angular/router';
import { AuthService } from '../../core/services/auth/auth.service';

export const adminGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  const isAdmin = authService.hasRole('ADMIN');

  if (isAdmin) {
    return true;
  }

  router.navigate(['/']);
  return false;
};
