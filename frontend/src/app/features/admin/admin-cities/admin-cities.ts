import { Component, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminCityApplyItem,
  AdminCityPreviewItem,
  AdminService,
  CountryOption,
} from '../../../core/services/admin/admin.service';
import { NotificationService } from '../../../core/services/notification/notification.service';

/** Une ligne d'aperçu + son état d'édition dans l'écran (sélection, nom corrigé, pays choisi) —
 *  même structure que l'écran de géocodage des arrêts (admin-geocoding.ts), mais gardée
 *  indépendante : celle-ci cible de vraies lignes City (id), pas de simples city_label. */
interface CityRow extends AdminCityPreviewItem {
  selected: boolean;
  editedName: string;
  /** Pays choisi pour le re-géocodage (code ISO) — initialisé au pays déjà connu de la ville
   *  si elle en a un, sinon vide (recherche mondiale). */
  countryCode: string;
  reGeocoding: boolean;
}

@Component({
  selector: 'app-admin-cities',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-cities.html',
  styleUrl: './admin-cities.scss',
})
export class AdminCities {
  private admin = inject(AdminService);
  private toast = inject(NotificationService);

  countries = signal<CountryOption[]>([]);
  rows = signal<CityRow[]>([]);
  loading = signal(false);
  applying = signal(false);
  loadError = signal<string | null>(null);
  hasLoadedOnce = signal(false);

  selectableRows = computed(() => this.rows().filter((r) => r.latitude != null && r.longitude != null));
  selectedCount = computed(() => this.rows().filter((r) => r.selected).length);

  /** Regroupe la liste des pays par continent pour l'affichage en <optgroup> — même principe que
   *  groupedCountryOptions() de l'écran de géocodage des arrêts, mais construit dynamiquement à
   *  partir de la vraie table Country plutôt que d'une liste figée côté frontend. */
  countryGroups = computed(() => {
    const groups = new Map<string, CountryOption[]>();
    for (const c of this.countries()) {
      const key = c.continent || 'Autres';
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key)!.push(c);
    }
    return Array.from(groups.entries()).map(([group, options]) => ({ group, options }));
  });

  constructor() {
    this.admin.getCountries().subscribe({
      next: (list) => this.countries.set(list),
      error: (err) => console.error('Erreur chargement des pays', err),
    });
  }

  private countryCodeFor(countryId: number | null): string {
    if (countryId == null) return '';
    return this.countries().find((c) => c.id === countryId)?.isoCode ?? '';
  }

  loadPreview() {
    this.loading.set(true);
    this.loadError.set(null);
    this.admin.previewCities().subscribe({
      next: (response) => {
        this.rows.set(
          response.items.map((item) => ({
            ...item,
            selected: item.latitude != null && item.longitude != null && !item.ambiguous,
            editedName: item.name,
            countryCode: this.countryCodeFor(item.countryId),
            reGeocoding: false,
          })),
        );
        this.loading.set(false);
        this.hasLoadedOnce.set(true);
      },
      error: (err) => {
        console.error('Erreur aperçu Pays & Villes', err);
        this.loadError.set(err?.error?.message || "Impossible de charger l'aperçu.");
        this.loading.set(false);
      },
    });
  }

  toggleRow(row: CityRow) {
    if (row.latitude == null || row.longitude == null) return;
    this.rows.update((list) => list.map((r) => (r.id === row.id ? { ...r, selected: !r.selected } : r)));
  }

  selectAllValid() {
    this.rows.update((list) =>
      list.map((r) => (r.latitude != null && r.longitude != null ? { ...r, selected: true } : r)),
    );
  }

  clearSelection() {
    this.rows.update((list) => list.map((r) => ({ ...r, selected: false })));
  }

  /** Retire la ligne de l'écran — jamais d'appel backend, purement un masquage local pour cette
   *  session (revue plus tard, aucune donnée modifiée). */
  ignoreRow(row: CityRow) {
    this.rows.update((list) => list.filter((r) => r.id !== row.id));
  }

  updateEditedName(row: CityRow, value: string) {
    this.rows.update((list) => list.map((r) => (r.id === row.id ? { ...r, editedName: value } : r)));
  }

  updateCountry(row: CityRow, value: string) {
    this.rows.update((list) => list.map((r) => (r.id === row.id ? { ...r, countryCode: value } : r)));
  }

  reGeocode(row: CityRow) {
    const query = row.editedName.trim();
    if (!query) {
      this.toast.show('Le nom de ville ne peut pas être vide.', 'error');
      return;
    }
    this.rows.update((list) => list.map((r) => (r.id === row.id ? { ...r, reGeocoding: true } : r)));
    this.admin.geocodeOneCity(row.id, query, row.countryCode || null).subscribe({
      next: (result) => {
        this.rows.update((list) =>
          list.map((r) =>
            r.id === row.id
              ? {
                  ...r,
                  latitude: result.latitude,
                  longitude: result.longitude,
                  ambiguous: result.ambiguous,
                  errorMessage: result.errorMessage,
                  reGeocoding: false,
                  selected: result.latitude != null && result.longitude != null && !result.ambiguous,
                }
              : r,
          ),
        );
      },
      error: (err) => {
        this.rows.update((list) => list.map((r) => (r.id === row.id ? { ...r, reGeocoding: false } : r)));
        this.toast.show(err?.error?.message || 'Échec du re-géocodage.', 'error');
      },
    });
  }

  apply() {
    const items: AdminCityApplyItem[] = this.rows()
      .filter((r) => r.selected && r.latitude != null && r.longitude != null)
      .map((r) => {
        const newName = r.editedName.trim();
        const renamed = newName && newName !== r.name;
        const country = this.countries().find((c) => c.isoCode === r.countryCode);
        return {
          id: r.id,
          name: renamed ? newName : null,
          countryId: country ? country.id : r.countryId,
          latitude: r.latitude as number,
          longitude: r.longitude as number,
        };
      });

    if (items.length === 0) {
      this.toast.show('Coche au moins une ville avant de valider.', 'error');
      return;
    }
    if (!confirm(`Valider ${items.length} ville(s) ? Cette action écrit en base immédiatement.`)) {
      return;
    }

    this.applying.set(true);
    this.admin.applyCities(items).subscribe({
      next: (response) => {
        this.applying.set(false);
        this.toast.show(
          `${response.appliedCount} ville(s) validée(s).`,
          response.appliedCount > 0 ? 'success' : 'info',
        );
        this.rows.update((list) => list.filter((r) => !response.appliedCityNames.includes(r.name)));
      },
      error: (err) => {
        this.applying.set(false);
        this.toast.show(err?.error?.message || "Échec de la validation.", 'error');
      },
    });
  }
}
