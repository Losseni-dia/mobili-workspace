/**
 * Correspondance hostname (navigateur) → URL API.
 * Staging (recette) : int.mobili.com + api.int.mobili.com — override possible via index.html (meta / __MOBILI_API_URL__).
 */
export const CONFIGURATION_DATA = {
  environments: [
    {
      env: 'local',
      domain: ['localhost:4200', '127.0.0.1:4200'],
    },
    {
      env: 'dev',
      domain: ['mobili.dev.ecode.be'],
    },
    {
      env: 'acc',
      domain: ['acc.mobili.example.com', 'mobili-acc.example.com'],
    },
    {
      /** Déploiement de recette HTTPS (tests, Capacitor) — non prod */
      env: 'staging',
      domain: [
        'app-staging.example.com',
        'www.app-staging.example.com',
        'staging.mobili.example.com',
      ],
    },
    {
      env: 'prod',
      domain: ['mobili.example.com', 'www.mobili.example.com'],
    },
  ],
  variables: {
    local: {
      apiUrl: 'http://localhost:8080/v1',
    },
    dev: {
      apiUrl: 'http://mobili.dev.ecode.be/v1',
    },
    acc: {
      apiUrl: 'https://api-acc.mobili.example.com/v1',
    },
    staging: {
      apiUrl: 'https://api.int.mobili.com/v1',
    },
    prod: {
      apiUrl: 'https://api.mobili.example.com/v1',
    },
  },
};