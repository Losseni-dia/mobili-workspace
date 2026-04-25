/**
 * Correspondance hostname (navigateur) → URL API.
 * Ajoutez vos domaines réels (acc, prod) quand ils existent.
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
    prod: {
      apiUrl: 'https://api.mobili.example.com/v1',
    },
  },
};