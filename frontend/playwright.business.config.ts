import { defineConfig, devices } from '@playwright/test';

/** E2E smoke Mobili Business (port 4201) — indépendant du serveur voyageur. */
const useWebServer = process.env.PLAYWRIGHT_SKIP_WEBSERVER !== '1';

export default defineConfig({
  testDir: './e2e-business',
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    ...devices['Desktop Chrome'],
    baseURL: process.env.MOBILI_BUSINESS_BASE_URL ?? 'http://127.0.0.1:4201',
    trace: 'retain-on-failure',
  },
  webServer: useWebServer
    ? {
        command:
          'npm run start:business -- --host 127.0.0.1 --port 4201 --configuration development',
        cwd: __dirname,
        url: 'http://127.0.0.1:4201',
        reuseExistingServer: !process.env.CI,
        timeout: 240_000,
      }
    : undefined,
});
