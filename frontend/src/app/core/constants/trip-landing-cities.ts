import citiesData from './trip-landing-cities.json';

// ─────────────────────────────────────────────────────────────────────────────
// Villes ciblées par les pages de trajets indexables (/trajets/:from/:to)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Portée validée avec l'utilisateur : Abidjan (hub) + 29 chefs-lieux de région ivoiriens +
 * 9 capitales de la sous-région (7 UEMOA + Accra/Conakry, déjà mentionnées dans la meta
 * description du site). Source unique de vérité — importée ici ET par
 * scripts/generate-sitemap.mjs (JSON, lisible des deux côtés sans duplication).
 *
 * `name` est le nom exact à envoyer à l'API (`GET /trips/search?departure=...`) — le backend
 * (TripService.java, normalizeCityToken) matche les villes par préfixe après mise en minuscule
 * SEULEMENT, sans suppression d'accents. Envoyer "bouake" (slug, sans accent) ne matcherait
 * jamais "Bouaké" en base — d'où la nécessité de stocker le vrai nom accentué à côté du slug,
 * pas de le reconstruire algorithmiquement à l'aller-retour.
 */
export interface TripLandingCity {
  slug: string;
  name: string;
}

export const TRIP_LANDING_CITIES: readonly TripLandingCity[] = citiesData.cities;

export const ABIDJAN_SLUG = 'abidjan';

const CITIES_BY_SLUG = new Map(TRIP_LANDING_CITIES.map((c) => [c.slug, c]));

export function findCityBySlug(slug: string): TripLandingCity | undefined {
  return CITIES_BY_SLUG.get(slug.toLowerCase());
}

export function buildLandingPath(fromSlug: string, toSlug: string): string {
  return `/trajets/${fromSlug}/${toSlug}`;
}
