import { HttpErrorResponse, HttpEvent, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth/auth.service';
import { catchError, Observable, switchMap, throwError } from 'rxjs';

import { skipAuthRefreshRetry } from '../http/auth-refresh.context';

export interface AuthResponse {
  token: string;
  login: string;
  userId: number;
  firstName: string; // Ajouté pour matcher le Backend
  lastName: string; // Ajouté pour matcher le Backend
  name?: string; // Optionnel si tu gardes la concaténation
  avatar: string; // C'est ton avatarUrl
  roles: string[];
}

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  const doAuth = (attempt: number): Observable<HttpEvent<unknown>> => {
    const u = authService.currentUser();
    if (!u?.token) {
      return next(req);
    }
    const authReq = req.clone({
      setHeaders: { Authorization: `Bearer ${u.token}` },
    });
    return next(authReq).pipe(
      catchError((error: HttpErrorResponse) => {
        if (
          error.status === 401 &&
          attempt === 0 &&
          !req.context.get(skipAuthRefreshRetry)
        ) {
          return authService.refreshAccessTokenFromCookie().pipe(
            switchMap((ok) => {
              if (!ok) {
                authService.logout();
                router.navigate(['/auth/login']);
                return throwError(() => error);
              }
              if (!authService.currentUser()?.token) {
                authService.logout();
                router.navigate(['/auth/login']);
                return throwError(() => error);
              }
              return doAuth(1);
            }),
          );
        }
        if (u && (error.status === 401 || error.status === 403)) {
          authService.logout();
          router.navigate(['/auth/login']);
        }
        return throwError(() => error);
      }),
    );
  };

  if (authService.currentUser()?.token) {
    return doAuth(0);
  }
  return next(req);
};
