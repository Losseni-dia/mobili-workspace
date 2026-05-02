/**
 * Correspondance hostname (navigateur) → URL API.
 * Partagé entre l’appli voyageur (port 4200) et Mobili Business (port 4201).
 */
export const CONFIGURATION_DATA = {
  environments: [
    {
      env: 'local',
      domain: [
        'localhost:4200',
        '127.0.0.1:4200',
        'localhost:4201',
        '127.0.0.1:4201',
        'localhost',
        '127.0.0.1',
      ],
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
      /** Appli « Mobili Business » (partenaire, gare) — sans / final */
      businessWebBase: 'http://localhost:4201',
      /** Appli voyageur (réservations) — liens depuis Mobili Business */
      travelerWebBase: 'http://localhost:4200',
    },
    dev: {
      apiUrl: 'http://mobili.dev.ecode.be/v1',
      businessWebBase: 'https://business.mobili.dev.ecode.be',
      travelerWebBase: 'https://mobili.dev.ecode.be',
    },
    acc: {
      apiUrl: 'https://api-acc.mobili.example.com/v1',
      businessWebBase: 'https://business-acc.mobili.example.com',
      travelerWebBase: 'https://mobili-acc.example.com',
    },
    staging: {
      apiUrl: 'https://api.int.mobili.ci/v1',
      businessWebBase: 'https://business.int.mobili.ci',
    },
    prod: {
      apiUrl: 'https://api.mobili.example.com/v1',
      businessWebBase: 'https://business.mobili.example.com',
      travelerWebBase: 'https://mobili.example.com',
    },
  },
} as const;
