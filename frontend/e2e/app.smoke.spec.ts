import { test, expect } from '@playwright/test';

test.describe('Mobili voyageur — fumée', () => {
  test('accueil affiche le héros', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByTestId('home-hero-title')).toBeVisible();
    await expect(page.getByTestId('home-hero-title')).toContainText('Mobili');
  });

  test('formulaire de recherche présent', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('form.search-form')).toBeVisible();
    await expect(page.getByPlaceholder(/D'où partez-vous/i)).toBeVisible();
  });

  test('écran connexion', async ({ page }) => {
    await page.goto('/auth/login');
    await expect(page.getByRole('heading', { name: 'Connexion' })).toBeVisible();
  });
});
