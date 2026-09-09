import { Component, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  AdminService,
  GeocodingApplyItem,
  GeocodingPreviewItem,
} from '../../../core/services/admin/admin.service';
import { NotificationService } from '../../../core/services/notification/notification.service';

/** Une ligne d'aperçu + son état de sélection dans l'écran (checkbox coché/décoché). */
interface GeocodingRow extends GeocodingPreviewItem {
  selected: boolean;
}

@Component({
  selector: 'app-admin-geocoding',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './admin-geocoding.html',
  styleUrl: './admin-geocoding.scss',
})
export class AdminGeocoding {
  private admin = inject(AdminService);
  private toast = inject(NotificationService);

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

  apply() {
    const items: GeocodingApplyItem[] = this.rows()
      .filter((r) => r.selected && r.latitude != null && r.longitude != null)
      .map((r) => ({ cityLabel: r.cityLabel, latitude: r.latitude as number, longitude: r.longitude as number }));

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
