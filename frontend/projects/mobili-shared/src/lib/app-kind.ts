/**
 * Marqueur produit pour distinguer l’appli « voyageur » (frontend racine) et « business »
 * (projects/mobili-business). Sera complété (tokens API, thème) au fil des extractions.
 */
export const MOBILI_APP_PRODUCT = {
  user: 'mobili',
  business: 'mobili-business',
} as const;

export type MobiliAppProductId = (typeof MOBILI_APP_PRODUCT)[keyof typeof MOBILI_APP_PRODUCT];

export function mobiliBusinessShellTitle(): string {
  return 'Mobili Business';
}
