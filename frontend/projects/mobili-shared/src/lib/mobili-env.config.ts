/**
 * Configuration harmonisée pour Mobili (Dev & Prod).
 */
export const CONFIGURATION_DATA = {
  environments: [
    {
      env: 'local',
      // Domaines de développement (ng serve)
      domain: ['localhost:4200', '127.0.0.1:4200', 'localhost:4201', '127.0.0.1:4201'],
    },
    {
      env: 'prod',
      // Domaines de production réels
      domain: ['my-mobili.com', 'www.my-mobili.com', 'business.my-mobili.com'],
    },
  ],
  variables: {
    local: {
      /** Même origine que `ng serve` → cookies refresh + CORS cohérents (proxy `/v1`). */
      apiUrl: '/v1',
      businessWebBase: 'http://localhost:4201',
      travelerWebBase: 'http://localhost:4200',
    },
    prod: {
      /** Nginx système proxifie `/v1` vers le backend. */
      apiUrl: '/v1',
      businessWebBase: 'https://business.my-mobili.com',
      travelerWebBase: 'https://www.my-mobili.com',
    },
  },
} as const;
