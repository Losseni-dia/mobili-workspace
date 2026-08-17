import { MobiliAppKind } from '../config/mobili-app-kind.token';
import { AuthService } from '../services/auth/auth.service';
import { ConfigurationService } from '../../configurations/services/configuration.service';

/**
 * Cible après login réussi (évite boucle `/` → `auth/login` sur Mobili Business).
 */
export function postLoginNavigateUrl(options: {
  kind: MobiliAppKind;
  auth: AuthService;
  configuration: ConfigurationService;
  returnUrlRaw: string | null | undefined;
}): string {
  const raw = options.returnUrlRaw?.trim();
  if (
    raw &&
    raw.startsWith('/') &&
    !raw.startsWith('//') &&
    !raw.includes('..') &&
    !raw.startsWith('/auth/')
  ) {
    return raw.includes('?') ? raw.split('?')[0] ?? raw : raw;
  }

  const a = options.auth;

  if (options.kind === 'business') {
    if (a.hasRole('ADMIN')) {
      return `${options.configuration.getTravelerWebBaseUrl()}/admin/dashboard`;
    }
    if (a.hasRole('GARE') || a.hasRole('STATION')) {
      return '/gare/accueil';
    }
    if (a.hasRole('PARTNER')) {
      return '/partenaire/dashboard';
    }
    if (a.hasRole('CHAUFFEUR')) {
      return '/covoiturage/accueil';
    }
    return '/auth/portail';
  }

  /** Appli voyageur */
  const biz = options.configuration.getBusinessWebBaseUrl();
  if (a.hasRole('ADMIN')) return '/admin/dashboard';
  if (a.hasRole('PARTNER')) return `${biz}/partenaire/dashboard`;
  if (a.hasRole('GARE') || a.hasRole('STATION')) return `${biz}/gare/accueil`;
  // ⚠️ Ne PAS rediriger automatiquement vers /covoiturage sur la seule présence du rôle
  // CHAUFFEUR : un compte "mixte" (passager qui a aussi été validé chauffeur covoiturage,
  // cf. UserService.registerCarpoolChauffeur qui ajoute CHAUFFEUR à un compte USER existant)
  // se connectant depuis l'app voyageur doit atterrir sur son dashboard passager, pas être
  // renvoyé de force vers l'espace conducteur (feedback testeurs). L'accès covoiturage reste
  // disponible via la nav normale.
  if (a.isLoggedIn()) return '/my-account/profile';
  return '/';
}
