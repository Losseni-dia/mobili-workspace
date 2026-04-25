import { Injectable } from '@angular/core';
import { CONFIGURATION_DATA } from '../../app.env.config';

@Injectable({
    providedIn: 'root'
})
export class ConfigurationService {
    private currentConfig: any;

    constructor() {
        const host = window.location.host;
        const envMatch = CONFIGURATION_DATA.environments.find(e =>
            e.domain.some(d => host.includes(d))
        );
        const envName = (envMatch ? envMatch.env : 'local') as keyof typeof CONFIGURATION_DATA.variables;
        this.currentConfig = CONFIGURATION_DATA.variables[envName] ?? CONFIGURATION_DATA.variables.local;
        console.log(`[Mobili Config] Mode détecté : ${envName}`);
    }

   getEnvironmentVariable(key: string): string | null {
    const value = this.currentConfig ? this.currentConfig[key] : null;
    return typeof value === 'string' && value.trim().length > 0 ? value : null;
  }
}