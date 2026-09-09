import { Component, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminService,
  GeocodingApplyItem,
  GeocodingPreviewItem,
} from '../../../core/services/admin/admin.service';
import { NotificationService } from '../../../core/services/notification/notification.service';

/** Pays desservis en pratique par Mobili — restreint la recherche Mapbox à ce pays pour lever
 *  une ambiguïté (ex. "Touba" CI vs SN) ou corriger un résultat aberrant (ex. "Pogo" -> Pologne).
 *  "" = recherche mondiale avec simple biais de proximité (comportement d'origine). */
export const GEOCODING_COUNTRY_OPTIONS: { code: string; label: string }[] = [
  { code: '', label: 'Aucun (recherche mondiale)' },
  { code: 'CI', label: "Côte d'Ivoire" },
  { code: 'SN', label: 'Sénégal' },
  { code: 'ML', label: 'Mali' },
  { code: 'BF', label: 'Burkina Faso' },
  { code: 'GH', label: 'Ghana' },
  { code: 'TG', label: 'Togo' },
  { code: 'BJ', label: 'Bénin' },
  { code: 'NE', label: 'Niger' },
  { code: 'GN', label: 'Guinée' },
  { code: 'BI', label: 'Burundi' },
  { code: 'MA', label: 'Maroc' },
];

/** Une ligne d'aperçu + son état d'édition dans l'écran (sélection, nom corrigé, pays choisi). */
interface GeocodingRow extends GeocodingPreviewItem {
  selected: boolean;
  /** Nom éventuellement corrigé par l'admin ("Modifier le nom") — égal à cityLabel tant que
   *  l'admin n'a rien changé. Envoyé comme newCityLabel à apply() seulement si différent. */
  editedLabel: string;
  /** Pays choisi pour restreindre le re-géocodage ("" = mondial, comportement d'origine). */
  country: string;
  /** Appel "Re-géocoder" en cours pour cette ligne uniquement. */
  reGeocoding: boolean;
}

@Component({
  selector: 'app-admin-geocoding',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-geocoding.html',
  styleUrl: './admin-geocoding.scss',
})
export class AdminGeocoding {
  private admin = inject(AdminService);
  private toast = inject(NotificationService);

  countryOptions = GEOCODING_COUNTRY_OPTIONS;

  rows = signal<GeocodingRow[]>([]);
  loading = signal(false);
  applying = signal(false);
  loadError = signal<string | null>(null);
  hasLoadedOnce = signal(false);

  /** Uniquement les lignes géocodées avec succès peuvent être sélectionnées — jamais une ligne
   *  en échec ou exclue comme donnée de test (pas de coordonnées à appliquer de toute façon). */
  selectableRows = computed(() => this.rows().filter((r) => r.latitude != null && r.longitude != null));
  selectedCount = computed(() => this.rows().filter((r) => r.selected).length);

  loadPreview() {
    this.loading.set(true);
    this.loadError.set(null);
    this.admin.previewTripStopGeocoding().subscribe({
      next: (response) => {
        this.rows.set(
          response.items.map((item) => ({
            ...item,
            // Pré-coché par défaut sauf pour les cas à vérifier manuellement (ambigu) — l'admin
            // reste libre de tout décocher/cocher avant de valider.
            selected: item.latitude != null && item.longitude != null && !item.ambiguous,
            editedLabel: item.cityLabel,
            country: '',
            reGeocoding: false,
          })),
        );
        this.loading.set(false);
        this.hasLoadedOnce.set(true);
      },
      error: (err) => {
        console.error('Erreur aperçu géocodage', err);
        this.loadError.set(err?.error?.message || "Impossible de charger l'aperçu.");
        this.loading.set(false);
      },
    });
  }

  toggleRow(row: GeocodingRow) {
    if (row.latitude == null || row.longitude == null) return;
    this.rows.update((list) =>
      list.map((r) => (r.cityLabel === row.cityLabel ? { ...r, selected: !r.selected } : r)),
    );
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
   *  session (ex. "Ffff"/"Ssss" déjà traitées manuellement ailleurs, pas la peine de les revoir). */
  ignoreRow(row: GeocodingRow) {
    this.rows.update((list) => list.filter((r) => r.cityLabel !== row.cityLabel));
  }

  updateEditedLabel(row: GeocodingRow, value: string) {
    this.rows.update((list) =>
      list.map((r) => (r.cityLabel === row.cityLabel ? { ...r, editedLabel: value } : r)),
    );
  }

  updateCountry(row: GeocodingRow, value: string) {
    this.rows.update((list) =>
      list.map((r) => (r.cityLabel === row.cityLabel ? { ...r, country: value } : r)),
    );
  }

  /** Relance Mapbox pour cette ligne avec le nom corrigé et/ou le pays choisi — ne touche jamais
   *  la base, juste un rafraîchissement de l'aperçu de cette ligne avant validation. */
  reGeocode(row: GeocodingRow) {
    const query = row.editedLabel.trim();
    if (!query) {
      this.toast.show('Le nom de ville ne peut pas être vide.', 'error');
      return;
    }
    this.rows.update((list) =>
      list.map((r) => (r.cityLabel === row.cityLabel ? { ...r, reGeocoding: true } : r)),
    );
    this.admin.geocodeOneTripStopCity(query, row.country || null).subscribe({
      next: (result) => {
        this.rows.update((list) =>
          list.map((r) =>
            r.cityLabel === row.cityLabel
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
        this.rows.update((list) =>
          list.map((r) => (r.cityLabel === row.cityLabel ? { ...r, reGeocoding: false } : r)),
        );
        this.toast.show(err?.error?.message || 'Échec du re-géocodage.', 'error');
      },
    });
  }

  apply() {
    const items: GeocodingApplyItem[] = this.rows()
      .filter((r) => r.selected && r.latitude != null && r.longitude != null)
      .map((r) => {
        const newLabel = r.editedLabel.trim();
        const renamed = newLabel && newLabel !== r.cityLabel;
        return {
          cityLabel: r.cityLabel,
          latitude: r.latitude as number,
          longitude: r.longitude as number,
          newCityLabel: renamed ? newLabel : null,
        };
      });

    if (items.length === 0) {
      this.toast.show('Coche au moins une ville avant de valider.', 'error');
      return;
    }
    if (!confirm(`Appliquer les coordonnées pour ${items.length} ville(s) ? Cette action écrit en base immédiatement.`)) {
      return;
    }

    this.applying.set(true);
    this.admin.applyTripStopGeocoding(items).subscribe({
      next: (response) => {
        this.applying.set(false);
        this.toast.show(
          `${response.appliedCount} ville(s) mise(s) à jour.`,
          response.appliedCount > 0 ? 'success' : 'info',
        );
        // Retire de la liste les lignes appliquées avec succès — celles en échec/non cochées
        // restent affichées pour un nouveau passage.
        this.rows.update((list) => list.filter((r) => !response.appliedCityLabels.includes(r.cityLabel)));
      },
      error: (err) => {
        this.applying.set(false);
        this.toast.show(err?.error?.message || "Échec de l'application des coordonnées.", 'error');
      },
    });
  }
}
