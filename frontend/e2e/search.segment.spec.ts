import { test, expect } from '@playwright/test';

/**
 * F30 — page résultats : segment affiché à partir des paramètres d’URL (`departure` / `arrival` / `date`).
 * Ne dépend pas de l’API (recette manuelle ou backend pour la liste des trajets).
 */
test.describe('F30 — recherche segmentée (page résultats)', () => {
  test('affiche le segment depuis la query string', async ({ page }) => {
    await page.goto('/search-results?departure=Abidjan&arrival=Yamoussoukro&date=2026-06-15');

    await expect(page.getByTestId('search-results-page')).toBeVisible();
    await expect(page.getByTestId('search-results-heading')).toContainText('Abidjan');
    await expect(page.getByTestId('search-results-heading')).toContainText('Yamoussoukro');
    await expect(page.getByTestId('search-results-heading')).toContainText('→');
  });
});
