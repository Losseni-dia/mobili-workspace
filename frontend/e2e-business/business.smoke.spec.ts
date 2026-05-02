import { test, expect } from '@playwright/test';

test.describe('Mobili Business — fumée', () => {
  test('écran connexion partenaire / pro', async ({ page }) => {
    await page.goto('/auth/login');
    await expect(page.getByRole('heading', { name: 'Connexion' })).toBeVisible();
  });
});
