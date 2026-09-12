import { DOCUMENT } from '@angular/common';
import { Injectable, inject } from '@angular/core';
import { Meta, Title } from '@angular/platform-browser';

// ─────────────────────────────────────────────────────────────────────────────
// SeoService — titre/description/Open Graph par page
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Avant ce service, index.html portait un <title>/<meta description> statiques et identiques
 * sur TOUTES les pages (accueil, CGU, connexion...) — aucun usage de Meta/Title Angular nulle
 * part dans le projet. Conséquence : mauvais taux de clic Google sur les pages secondaires, et
 * aucune balise Open Graph (un lien Mobili partagé sur WhatsApp/Facebook affichait un aperçu
 * vide ou générique).
 *
 * Meta/Title sont `providedIn: 'root'` — aucun provider à ajouter dans app.config.ts.
 *
 * Fonctionne aussi bien en SSR/Prerender (le service tourne pendant le rendu du composant, donc
 * les balises sont déjà dans le HTML statique généré au build) qu'en CSR (mise à jour à la
 * navigation) — même mécanisme, pas de branchement isPlatformBrowser nécessaire ici (Meta/Title
 * sont SSR-safe par construction, contrairement à un accès direct à `document`).
 */
export interface PageSeoConfig {
  title: string;
  description: string;
  /** Chemin relatif (ex. "/cgu") utilisé pour construire og:url. Défaut : "/" (accueil). */
  canonicalPath?: string;
  /** URL absolue. Défaut : logo Mobili (même asset que le JSON-LD Organization d'index.html). */
  ogImage?: string;
}

const SITE_ORIGIN = 'https://www.my-mobili.com';
const DEFAULT_OG_IMAGE = `${SITE_ORIGIN}/assets/images/ecrito-bleu.png`;
const JSONLD_SCRIPT_ID = 'seo-jsonld-page';

@Injectable({ providedIn: 'root' })
export class SeoService {
  private readonly titleService = inject(Title);
  private readonly meta = inject(Meta);
  // Le `document` global peut ne pas être l'instance réellement utilisée pour la sérialisation
  // pendant le prerendering (chaque requête SSR a sa propre instance isolée) — DOCUMENT est le
  // token Angular garantissant qu'on manipule le bon document, en SSR comme dans le navigateur.
  private readonly document = inject(DOCUMENT);

  setPageSeo(config: PageSeoConfig): void {
    const { title, description } = config;
    const canonicalPath = config.canonicalPath ?? '/';
    const ogImage = config.ogImage ?? DEFAULT_OG_IMAGE;
    const url = `${SITE_ORIGIN}${canonicalPath}`;

    this.titleService.setTitle(title);
    this.updateTag('description', description);

    this.updateTag('og:title', title, 'property');
    this.updateTag('og:description', description, 'property');
    this.updateTag('og:url', url, 'property');
    this.updateTag('og:type', 'website', 'property');
    this.updateTag('og:image', ogImage, 'property');

    this.updateTag('twitter:card', 'summary_large_image');
    this.updateTag('twitter:title', title);
    this.updateTag('twitter:description', description);
    this.updateTag('twitter:image', ogImage);
  }

  /**
   * Injecte un bloc JSON-LD spécifique à la page courante (en plus des Organization/WebSite
   * globaux déjà dans index.html). Retire l'ancien bloc avant d'en ajouter un nouveau — sans ça,
   * une navigation SPA client-side empilerait un <script> par page visitée.
   */
  setStructuredData(json: Record<string, unknown>): void {
    this.removeStructuredData();
    const script = this.document.createElement('script');
    script.type = 'application/ld+json';
    script.id = JSONLD_SCRIPT_ID;
    script.textContent = JSON.stringify(json);
    this.document.head.appendChild(script);
  }

  removeStructuredData(): void {
    this.document.getElementById(JSONLD_SCRIPT_ID)?.remove();
  }

  private updateTag(name: string, content: string, attr: 'name' | 'property' = 'name'): void {
    this.meta.updateTag({ [attr]: name, content });
  }
}
