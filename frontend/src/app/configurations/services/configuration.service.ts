import { Injectable } from '@angular/core';
import { CONFIGURATION_DATA } from 'mobili-shared';
import { resolveMobiliEnvName } from './resolve-env-name';

/** Normalise l’URL API (attendu par les interceptors : base avec /v1). */
function normalizeApiBase(url: string): string {
    const t = url.trim();
    if (!t) {
        return t;
    }
    return t.endsWith('/v1') ? t : `${t.replace(/\/$/, '')}/v1`;
}

@Injectable({
    providedIn: 'root'
})
export class ConfigurationService {
    private currentConfig: Record<string, string> & { apiUrl: string; businessWebBase: string; travelerWebBase?: string };

    constructor() {
        const override = this.readApiOverride();
        const envName = resolveMobiliEnvName();
        const base = { ...CONFIGURATION_DATA.variables[envName] } as Record<string, string>;
        if (override) {
            this.currentConfig = { ...base, apiUrl: override } as typeof this.currentConfig;
            console.log('[Mobili Config] Mode: override (meta / window) →', override, `(env: ${String(envName)})`);
        } else {
            this.currentConfig = base as typeof this.currentConfig;
            console.log(`[Mobili Config] Mode détecté : ${String(envName)}`);
        }
    }

    /**
     * Staging / Capacitor : injecte l’URL API sans dépendre du hostname.
     * 1) window.__MOBILI_API_URL__ (ex. balise script avant le bundle)
     * 2) <meta name="mobili-api-base" content="https://api…/v1">
     */
    private readApiOverride(): string | null {
        const w = window as unknown as { __MOBILI_API_URL__?: string };
        if (w.__MOBILI_API_URL__ && w.__MOBILI_API_URL__.trim().length > 0) {
            return normalizeApiBase(w.__MOBILI_API_URL__);
        }
        const meta = document.querySelector('meta[name="mobili-api-base"]')?.getAttribute('content');
        if (meta && meta.trim().length > 0) {
            return normalizeApiBase(meta);
        }
        return null;
    }

   getEnvironmentVariable(key: string): string | null {
    const value = this.currentConfig ? this.currentConfig[key] : null;
    return typeof value === 'string' && value.trim().length > 0 ? value : null;
  }

  /**
   * Racine des fichiers uploadés — **même hôte/port que l’API** (sans `/v1`), pas l’origine de la page.
   * Les `<img>` ne passent pas par l’intercepteur ; ne pas utiliser `localhost:4201/uploads` (proxy Vite souvent absent / 404).
   */
  getUploadBaseUrl(): string {
    const api = this.getEnvironmentVariable('apiUrl') ?? CONFIGURATION_DATA.variables.local.apiUrl;
    const withoutV1 = api.replace(/\/?v1\/?$/, '').replace(/\/$/, '');
    return `${withoutV1}/uploads/`;
  }

  /**
   * True pour les pièces KYC covoiturage (et autres préfixes sensibles) : lecture via {@code GET /v1/media/private} avec JWT.
   */
  isSensitiveUploadRelativePath(path: string | null | undefined): boolean {
    if (path == null || typeof path !== 'string') {
      return false;
    }
    const raw = path.trim();
    if (!raw || raw.includes('null')) {
      return false;
    }
    let rel = raw.replace(/^\/+/, '').replace(/^uploads\//, '');
    if (!rel) {
      return false;
    }
    const lower = rel.replace(/\\/g, '/').toLowerCase();
    return (
      lower.startsWith('sensitive/') ||
      lower.startsWith('covoiturage-ids/') ||
      lower.startsWith('covoiturage-drivers/') ||
      lower.startsWith('covoiturage-vehicles/') ||
      lower.startsWith(this.sensitiveDocumentsFolderPrefixLower())
    );
  }

  /** Aligné sur {@code mobili.backend.upload.documents-folder} (1er segment). Variable optionnelle {@code uploadDocumentsFolder} dans la config front. */
  private sensitiveDocumentsFolderPrefixLower(): string {
    const raw = (this.getEnvironmentVariable('uploadDocumentsFolder') ?? 'documents')
      .trim()
      .replace(/\\/g, '/')
      .replace(/^\/+/, '');
    const seg = raw.includes('/') ? raw.slice(0, raw.indexOf('/')) : raw;
    const base = seg.length > 0 ? seg : 'documents';
    return `${base.toLowerCase()}/`;
  }

  /** Encode chaque segment du chemin relatif (espaces, accents dans les noms de fichiers Windows). */
  private encodeUploadRelativePath(rel: string): string {
    return rel
      .replace(/\\/g, '/')
      .split('/')
      .filter((s) => s.length > 0)
      .map((segment) => encodeURIComponent(segment))
      .join('/');
  }

  /**
   * Construit l’URL complète d’un média stocké sous `uploads/` (avatars, logos, photos véhicule).
   * Gère les chemins relatifs (`users/…`, `vehicles/…`), les préfixes `uploads/` ou `/uploads/`, et les URLs absolues.
   */
  resolveUploadMediaUrl(path: string | null | undefined): string | null {
    if (path == null) {
      return null;
    }
    const raw = String(path).trim();
    if (!raw || raw.includes('null')) {
      return null;
    }
    if (/^https?:\/\//i.test(raw)) {
      return raw;
    }
    let rel = raw.replace(/^\/+/, '');
    rel = rel.replace(/^uploads\//, '');
    if (!rel) {
      return null;
    }
    if (this.isSensitiveUploadRelativePath(rel)) {
      return null;
    }
    rel = this.encodeUploadRelativePath(rel);
    const base = this.getUploadBaseUrl();
    return `${base}${rel}`;
  }

  /** Base URL (sans /) du site Mobili Business — redirection depuis l’appli voyageur. */
  getBusinessWebBaseUrl(): string {
    const v = this.getEnvironmentVariable('businessWebBase');
    if (v) {
      return v.replace(/\/$/, '');
    }
    return 'http://localhost:4201';
  }

  /** Site public voyageurs — liens depuis Mobili Business ou après login admin. */
  getTravelerWebBaseUrl(): string {
    const v = this.getEnvironmentVariable('travelerWebBase');
    if (v) {
      return v.replace(/\/$/, '');
    }
    return 'http://localhost:4200';
  }
}