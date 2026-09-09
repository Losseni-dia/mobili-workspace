import { RenderMode, ServerRoute } from '@angular/ssr';

/**
 * Mode de rendu par route, voir app.routes.ts pour la liste complète — décision du chantier SSR
 * (plan "Activer le rendu côté serveur (SSR) sur my-mobili.com") :
 *
 * - Prerender (HTML statique généré au build, servi par Nginx sans jamais toucher Node) : pages
 *   sans dépendance à une requête utilisateur — accueil, légal, formulaires d'auth (le contenu du
 *   formulaire est statique, seule la soumission est dynamique et reste côté client).
 * - Server (SSR à la demande, un vrai process Node) : uniquement /search-results, dont le contenu
 *   dépend des query params (villes/date recherchées) — impossible à prérendre à l'avance.
 * - Client (CSR pur, comportement identique à aujourd'hui) : tout ce qui est authentifié ou sans
 *   enjeu SEO (espace voyageur, redirections vers Mobili Business, chauffeur, admin, booking,
 *   paiement) — aucun bénéfice SEO, et ces pages dépendent de toute façon de l'état de connexion.
 */
export const serverRoutes: ServerRoute[] = [
  { path: '', renderMode: RenderMode.Prerender },
  { path: 'cgu', renderMode: RenderMode.Prerender },
  { path: 'confidentialite', renderMode: RenderMode.Prerender },
  { path: 'auth/login', renderMode: RenderMode.Prerender },
  { path: 'auth/inscription', renderMode: RenderMode.Prerender },
  { path: 'auth/register', renderMode: RenderMode.Prerender },
  { path: 'auth/register-carpool-chauffeur', renderMode: RenderMode.Prerender },

  { path: 'search-results', renderMode: RenderMode.Server },

  { path: 'my-account/**', renderMode: RenderMode.Client },
  { path: 'partenaire/**', renderMode: RenderMode.Client },
  { path: 'gare/**', renderMode: RenderMode.Client },
  { path: 'covoiturage/**', renderMode: RenderMode.Client },
  { path: 'chauffeur/**', renderMode: RenderMode.Client },
  { path: 'admin/**', renderMode: RenderMode.Client },
  { path: 'booking/**', renderMode: RenderMode.Client },
  { path: 'payment/**', renderMode: RenderMode.Client },

  // Repli pour toute route future non explicitement listée ici : CSR, jamais de prerender
  // "à l'aveugle" d'une page pas encore auditée pour la SSR-safety.
  { path: '**', renderMode: RenderMode.Client },
];
