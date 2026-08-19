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
  // ⚠️ Ne PAS rediriger automatiquement vers l'espace pro (business) sur la seule présence
  // d'un rôle PARTNER/GARE/STATION/CHAUFFEUR : un compte "mixte" (qui a AUSSI le rôle USER —
  // ex. passager devenu dirigeant/gare/chauffeur sans perdre son identité voyageur, cf.
  // UserService.registerCarpoolChauffeur qui ajoute CHAUFFEUR à un compte USER existant) se
  // connectant depuis l'app voyageur doit atterrir sur son dashboard passager, pas être
  // renvoyé de force vers l'espace pro (bug remonté : un compte USER+PARTNER se connectant sur
  // l'app voyageur était éjecté vers l'interface pro sans passer par l'accueil voyageur).
  // L'accès pro/covoiturage reste disponible via la nav normale.
  if (a.hasRole('PARTNER') && !a.hasRole('USER')) return `${biz}/partenaire/dashboard`;
  if ((a.hasRole('GARE') || a.hasRole('STATION')) && !a.hasRole('USER')) return `${biz}/gare/accueil`;
  if (a.isLoggedIn()) return '/my-account/profile';
  return '/';
}
