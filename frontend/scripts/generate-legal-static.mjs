#!/usr/bin/env node
/**
 * Génère une version HTML statique (sans JS) des pages légales, servie directement par Nginx
 * pour les requêtes qui n'exécutent pas de JavaScript (crawlers, robots de vérification
 * Google Play, curl...) — la version interactive Angular (SPA) reste utilisée pour toute
 * navigation normale dans l'app.
 *
 * Source unique de vérité : les fichiers JSON dans src/app/features/legal/*.json, aussi
 * importés par les composants Angular (confidentialite.component.ts / cgu.component.ts).
 * Ne jamais modifier le texte ici — modifier le JSON, puis relancer ce script.
 *
 * Sortie : frontend/public/<route>/index.html — Angular copie public/** tel quel dans le
 * bundle (voir angular.json > assets), et Nginx (try_files $uri $uri/ /index.html) sert donc
 * ce fichier statique en priorité pour une requête GET /<route> ou /<route>/, sans changement
 * de config Nginx. La navigation interne (routerLink, SPA) n'est pas affectée : elle ne passe
 * jamais par une requête HTTP complète vers ce fichier.
 *
 * Usage : node scripts/generate-legal-static.mjs (appelé automatiquement avant chaque build,
 * voir package.json > "prebuild").
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');

/** @param {string} s */
function escapeHtml(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const PAGES = [
  {
    route: 'confidentialite',
    jsonPath: 'src/app/features/legal/confidentialite-content.json',
    title: 'Politique de Confidentialité — Mobili',
    heroIcon: '🛡️',
    heroTitle: 'Politique de Confidentialité & Protection des Données',
    description:
      "Politique de confidentialité de Mobili : données collectées, finalités, durées de conservation, vos droits et la suppression de compte et de données.",
    hasIntro: true,
  },
  {
    route: 'cgu',
    jsonPath: 'src/app/features/legal/cgu-content.json',
    title: "Conditions Générales d'Utilisation — Mobili",
    heroIcon: '📄',
    heroTitle: "Conditions Générales d'Utilisation",
    description: "Conditions générales d'utilisation de la plateforme Mobili (billetterie et covoiturage).",
    hasIntro: false,
  },
];

for (const page of PAGES) {
  const data = JSON.parse(readFileSync(path.join(root, page.jsonPath), 'utf8'));

  const introHtml =
    page.hasIntro && data.intro ? `<p class="legal-intro">${escapeHtml(data.intro)}</p>` : '';

  const sectionsHtml = data.sections
    .map(
      (s) => `
      <section class="legal-section">
        <header class="legal-section-head">
          <span class="legal-section-num">${escapeHtml(s.number)}</span>
          <h2>${escapeHtml(s.title)}</h2>
        </header>
        <p class="legal-section-body">${escapeHtml(s.content)}</p>
      </section>`,
    )
    .join('\n');

  const html = `<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <title>${escapeHtml(page.title)}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${escapeHtml(page.description)}">
  <link rel="canonical" href="https://www.my-mobili.com/${page.route}">
  <link rel="icon" type="image/x-icon" href="/favicon.ico">
  <style>
    :root { color-scheme: light; }
    body { margin: 0; padding: 32px 20px 64px; max-width: 720px; margin-inline: auto; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; color: #2b2f38; background: #fff; line-height: 1.5; }
    a.back { display: inline-block; margin-bottom: 20px; font-weight: 700; color: #1b5fd6; text-decoration: none; }
    a.back:hover { text-decoration: underline; }
    .hero { padding: 24px; border-radius: 16px; background: linear-gradient(135deg, #1b5fd6, #123a86); color: #fff; margin-bottom: 16px; }
    .hero .icon { font-size: 1.8rem; display: block; margin-bottom: 10px; }
    .hero h1 { margin: 0 0 6px; font-size: 1.5rem; font-weight: 900; }
    .hero .version { margin: 0; font-size: 0.85rem; color: rgba(255,255,255,0.8); }
    .legal-intro { margin: 0 0 20px; padding: 14px 16px; border-radius: 8px; background: #eef4fd; border: 1px solid rgba(27,95,214,0.2); color: #123a86; font-size: 0.92rem; }
    .legal-section { background: #fff; border: 1px solid #e6e8ec; border-radius: 12px; overflow: hidden; margin-bottom: 16px; }
    .legal-section-head { display: flex; align-items: center; gap: 10px; padding: 14px 16px 10px; background: rgba(27,95,214,0.05); border-bottom: 1px solid #f0f1f3; }
    .legal-section-head h2 { margin: 0; font-size: 1.05rem; font-weight: 700; color: #123a86; }
    .legal-section-num { display: grid; place-items: center; width: 28px; height: 28px; flex-shrink: 0; border-radius: 8px; background: #1b5fd6; color: #fff; font-size: 0.85rem; font-weight: 800; }
    .legal-section-body { margin: 0; padding: 16px; white-space: pre-line; font-size: 0.95rem; color: #40454e; }
    noscript.js-note { display: block; margin-top: 24px; padding: 12px 16px; border-radius: 8px; background: #fff8e6; border: 1px solid #f0d998; font-size: 0.85rem; color: #6b5300; }
  </style>
</head>
<body>
  <a class="back" href="/">← Retour à l'accueil</a>
  <header class="hero">
    <span class="icon" aria-hidden="true">${page.heroIcon}</span>
    <h1>${escapeHtml(page.heroTitle)}</h1>
    <p class="version">${escapeHtml(data.version)}</p>
  </header>
  ${introHtml}
  <div class="legal-sections">${sectionsHtml}
  </div>
</body>
</html>
`;

  const outDir = path.join(root, 'public', page.route);
  mkdirSync(outDir, { recursive: true });
  writeFileSync(path.join(outDir, 'index.html'), html, 'utf8');
  console.log(`[generate-legal-static] écrit public/${page.route}/index.html`);
}
