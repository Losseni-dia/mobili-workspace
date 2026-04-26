/**
 * Correspondance hostname (navigateur) → URL API.
 * Staging (recette) : int.mobili.ci + api.int.mobili.ci — override possible via index.html (meta / __MOBILI_API_URL__).
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
      /** Recette intégration (HTTPS, tests, Capacitor) — non prod */
      env: 'staging',
      domain: ['int.mobili.ci', 'www.int.mobili.ci'],
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
      apiUrl: 'https://api.int.mobili.ci/v1',
    },
    prod: {
      apiUrl: 'https://api.mobili.example.com/v1',
    },
  },
};