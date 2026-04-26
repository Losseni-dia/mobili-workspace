import { Injectable } from '@angular/core';
import { CONFIGURATION_DATA } from '../../app.env.config';

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
    private currentConfig: any;

    constructor() {
        const override = this.readApiOverride();
        if (override) {
            this.currentConfig = { apiUrl: override };
            console.log('[Mobili Config] Mode: override (meta / window) →', override);
            return;
        }
        const host = window.location.hostname;
        const envMatch = CONFIGURATION_DATA.environments.find(e =>
            e.domain.some(d => d === host)
        );
        const envName = (envMatch ? envMatch.env : 'local') as keyof typeof CONFIGURATION_DATA.variables;
        this.currentConfig = CONFIGURATION_DATA.variables[envName] ?? CONFIGURATION_DATA.variables.local;
        console.log(`[Mobili Config] Mode détecté : ${envName}`);
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
}