import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { ConfigurationService } from '../../configurations/services/configuration.service'

// Dans ton apiInterceptor
export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  const configService = inject(ConfigurationService);
  const apiUrl = configService.getEnvironmentVariable('apiUrl');

  // BONNE PRATIQUE : Ne pas toucher aux URLs qui commencent déjà par http ou aux assets
  if (req.url.startsWith('http') || req.url.startsWith('./assets')) {
    return next(req);
  }

  if (!apiUrl) {
    throw new Error('Configuration invalide: apiUrl manquant pour les appels HTTP.');
  }

  const apiReq = req.clone({
    url: `${apiUrl}${req.url}`,
    withCredentials: true,
  });

  return next(apiReq);
};