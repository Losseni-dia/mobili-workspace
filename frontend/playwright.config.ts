import { defineConfig, devices } from '@playwright/test';

/**
 * Smoke E2E voyageur (http://127.0.0.1:4200).
 *
 * Local : lancer `npm start` dans un autre terminal puis `npm run e2e` (reuse du serveur).
 * Ou laisser Playwright démarrer `ng serve` (plus lent au premier run).
 *
 * CI : `CI=true` → redémarrage garanti, sans réutiliser un serveur externe.
 */
const useWebServer = process.env.PLAYWRIGHT_SKIP_WEBSERVER !== '1';

export default defineConfig({
  testDir: './e2e',
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    ...devices['Desktop Chrome'],
    baseURL: process.env.MOBILI_BASE_URL ?? 'http://127.0.0.1:4200',
    trace: 'retain-on-failure',
  },
  webServer: useWebServer
    ? {
        command: 'npm run start -- --host 127.0.0.1 --port 4200 --configuration development',
        cwd: __dirname,
        url: 'http://127.0.0.1:4200',
        reuseExistingServer: !process.env.CI,
        timeout: 240_000,
      }
    : undefined,
});
