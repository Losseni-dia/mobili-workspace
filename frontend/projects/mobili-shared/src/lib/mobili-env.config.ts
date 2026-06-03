/**
 * Configuration harmonisée pour Mobili (Dev & Prod).
 */
export const CONFIGURATION_DATA = {
  environments: [
    {
      env: 'local',
      // Domaines de développement
      domain: ['localhost:4200', '127.0.0.1:4200', 'localhost:4201', '127.0.0.1:4201'],
    },
    {
      env: 'prod',
      // Domaines de production (Docker Compose Prod)
      domain: [
        'localhost',
        'localhost:80',
        'localhost:81',
        '127.0.0.1',
        '127.0.0.1:80',
        '127.0.0.1:81',
        'mobili.ci',
        'www.mobili.ci',
      ],
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
      /** Nginx proxifie `/v1` vers le backend (voir nginx*.conf). */
      apiUrl: '/v1',

      /** Port 81 pour le Business */
      businessWebBase: 'http://localhost:81/mobili-workspace',

      /** Port 80 pour l'User */
      travelerWebBase: 'http://localhost:80',
    },
  },
} as const;
