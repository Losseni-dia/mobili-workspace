#!/usr/bin/env node
/**
 * Génère public/sitemap.xml — my-mobili.com n'en avait aucun (GET /sitemap.xml retombait sur la
 * coquille SPA comme n'importe quelle route inconnue), donc rien n'était jamais soumis à Google.
 *
 * Source unique de vérité pour les URLs listées : les routes en RenderMode.Prerender de
 * src/app/app.routes.server.ts, à l'exception des pages d'authentification (peu de valeur SEO,
 * volontairement exclues du sitemap même si crawlables). Si une route prerendered est
 * ajoutée/retirée là-bas, mettre à jour SITEMAP_ROUTES ci-dessous en conséquence — même
 * discipline que scripts/generate-legal-static.mjs (PAGES dupliqué volontairement, pas d'import
 * cross-toolchain TS→mjs).
 *
 * Usage : node scripts/generate-sitemap.mjs (appelé automatiquement avant chaque build, voir
 * package.json > "prebuild").
 */
import { writeFileSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');

const SITE_ORIGIN = 'https://www.my-mobili.com';

const SITEMAP_ROUTES = [
  { path: '', changefreq: 'daily', priority: '1.0' },
  { path: 'cgu', changefreq: 'yearly', priority: '0.3' },
  { path: 'confidentialite', changefreq: 'yearly', priority: '0.3' },
];

// Pages de trajets indexables (/trajets/:from/:to) — backlog SEO section 2bis. Source unique de
// vérité pour la liste des villes : src/app/core/constants/trip-landing-cities.json, importée
// aussi côté Angular (city-pair-landing.component.ts) — JSON lisible nativement des deux côtés,
// pas de duplication manuelle comme SITEMAP_ROUTES ci-dessus (acceptable pour 3 entrées, pas pour
// 39 villes). Une entrée par paire ordonnée Abidjan↔ville (les deux sens), jamais ville↔ville
// entre deux villes non-Abidjan (portée validée avec l'utilisateur : Abidjan comme hub unique).
const cityLandingPath = path.join(
  root,
  'src',
  'app',
  'core',
  'constants',
  'trip-landing-cities.json',
);
const { cities } = JSON.parse(readFileSync(cityLandingPath, 'utf8'));
const ABIDJAN_SLUG = 'abidjan';
const destinations = cities.filter((c) => c.slug !== ABIDJAN_SLUG);
const TRIP_LANDING_ROUTES = destinations.flatMap((city) => [
  { path: `trajets/${ABIDJAN_SLUG}/${city.slug}`, changefreq: 'daily', priority: '0.6' },
  { path: `trajets/${city.slug}/${ABIDJAN_SLUG}`, changefreq: 'daily', priority: '0.6' },
]);

// Date du jour (build), pas une date par page réelle — suffisant pour des pages quasi-statiques,
// évite de maintenir une date de dernière modification à la main pour chaque route.
const LASTMOD = new Date().toISOString().slice(0, 10);

const urlsXml = [...SITEMAP_ROUTES, ...TRIP_LANDING_ROUTES].map(
  ({ path: p, changefreq, priority }) => `  <url>
    <loc>${SITE_ORIGIN}/${p}</loc>
    <lastmod>${LASTMOD}</lastmod>
    <changefreq>${changefreq}</changefreq>
    <priority>${priority}</priority>
  </url>`,
).join('\n');

const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urlsXml}
</urlset>
`;

writeFileSync(path.join(root, 'public', 'sitemap.xml'), xml, 'utf8');
console.log('[generate-sitemap] écrit public/sitemap.xml');
