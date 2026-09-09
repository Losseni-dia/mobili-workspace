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
import { writeFileSync } from 'node:fs';
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

const urlsXml = SITEMAP_ROUTES.map(
  ({ path: p, changefreq, priority }) => `  <url>
    <loc>${SITE_ORIGIN}/${p}</loc>
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
