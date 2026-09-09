import { Component, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminService,
  GeocodingApplyItem,
  GeocodingPreviewItem,
} from '../../../core/services/admin/admin.service';
import { NotificationService } from '../../../core/services/notification/notification.service';

/** Restreint la recherche Mapbox à ce pays pour lever une ambiguïté (ex. "Touba" CI vs SN) ou
 *  corriger un résultat aberrant (ex. "Pogo" -> Pologne, "Bruxelles" -> hameau français près de
 *  Chartres). "" = recherche mondiale avec simple biais de proximité (comportement d'origine).
 *  Couvre l'Afrique (trajets réels de la plateforme) ET l'Europe (tests ponctuels type Bruxelles
 *  -> Côte d'Ivoire, voir historique tracking temps réel). */
export const GEOCODING_COUNTRY_OPTIONS: { code: string; label: string; group: string }[] = [
  { code: '', label: 'Aucun (recherche mondiale)', group: '' },

  { code: 'DZ', label: 'Algérie', group: 'Afrique' },
  { code: 'AO', label: 'Angola', group: 'Afrique' },
  { code: 'BJ', label: 'Bénin', group: 'Afrique' },
  { code: 'BW', label: 'Botswana', group: 'Afrique' },
  { code: 'BF', label: 'Burkina Faso', group: 'Afrique' },
  { code: 'BI', label: 'Burundi', group: 'Afrique' },
  { code: 'CV', label: 'Cap-Vert', group: 'Afrique' },
  { code: 'CM', label: 'Cameroun', group: 'Afrique' },
  { code: 'CF', label: 'République centrafricaine', group: 'Afrique' },
  { code: 'TD', label: 'Tchad', group: 'Afrique' },
  { code: 'KM', label: 'Comores', group: 'Afrique' },
  { code: 'CG', label: 'Congo', group: 'Afrique' },
  { code: 'CD', label: 'RD Congo', group: 'Afrique' },
  { code: 'DJ', label: 'Djibouti', group: 'Afrique' },
  { code: 'EG', label: 'Égypte', group: 'Afrique' },
  { code: 'GQ', label: 'Guinée équatoriale', group: 'Afrique' },
  { code: 'ER', label: 'Érythrée', group: 'Afrique' },
  { code: 'SZ', label: 'Eswatini', group: 'Afrique' },
  { code: 'ET', label: 'Éthiopie', group: 'Afrique' },
  { code: 'GA', label: 'Gabon', group: 'Afrique' },
  { code: 'GM', label: 'Gambie', group: 'Afrique' },
  { code: 'GH', label: 'Ghana', group: 'Afrique' },
  { code: 'GN', label: 'Guinée', group: 'Afrique' },
  { code: 'GW', label: 'Guinée-Bissau', group: 'Afrique' },
  { code: 'CI', label: "Côte d'Ivoire", group: 'Afrique' },
  { code: 'KE', label: 'Kenya', group: 'Afrique' },
  { code: 'LS', label: 'Lesotho', group: 'Afrique' },
  { code: 'LR', label: 'Liberia', group: 'Afrique' },
  { code: 'LY', label: 'Libye', group: 'Afrique' },
  { code: 'MG', label: 'Madagascar', group: 'Afrique' },
  { code: 'MW', label: 'Malawi', group: 'Afrique' },
  { code: 'ML', label: 'Mali', group: 'Afrique' },
  { code: 'MR', label: 'Mauritanie', group: 'Afrique' },
  { code: 'MU', label: 'Maurice', group: 'Afrique' },
  { code: 'MA', label: 'Maroc', group: 'Afrique' },
  { code: 'MZ', label: 'Mozambique', group: 'Afrique' },
  { code: 'NA', label: 'Namibie', group: 'Afrique' },
  { code: 'NE', label: 'Niger', group: 'Afrique' },
  { code: 'NG', label: 'Nigeria', group: 'Afrique' },
  { code: 'RW', label: 'Rwanda', group: 'Afrique' },
  { code: 'ST', label: 'Sao Tomé-et-Principe', group: 'Afrique' },
  { code: 'SN', label: 'Sénégal', group: 'Afrique' },
  { code: 'SC', label: 'Seychelles', group: 'Afrique' },
  { code: 'SL', label: 'Sierra Leone', group: 'Afrique' },
  { code: 'SO', label: 'Somalie', group: 'Afrique' },
  { code: 'ZA', label: 'Afrique du Sud', group: 'Afrique' },
  { code: 'SS', label: 'Soudan du Sud', group: 'Afrique' },
  { code: 'SD', label: 'Soudan', group: 'Afrique' },
  { code: 'TZ', label: 'Tanzanie', group: 'Afrique' },
  { code: 'TG', label: 'Togo', group: 'Afrique' },
  { code: 'TN', label: 'Tunisie', group: 'Afrique' },
  { code: 'UG', label: 'Ouganda', group: 'Afrique' },
  { code: 'ZM', label: 'Zambie', group: 'Afrique' },
  { code: 'ZW', label: 'Zimbabwe', group: 'Afrique' },

  { code: 'AL', label: 'Albanie', group: 'Europe' },
  { code: 'AD', label: 'Andorre', group: 'Europe' },
  { code: 'AT', label: 'Autriche', group: 'Europe' },
  { code: 'BY', label: 'Biélorussie', group: 'Europe' },
  { code: 'BE', label: 'Belgique', group: 'Europe' },
  { code: 'BA', label: 'Bosnie-Herzégovine', group: 'Europe' },
  { code: 'BG', label: 'Bulgarie', group: 'Europe' },
  { code: 'HR', label: 'Croatie', group: 'Europe' },
  { code: 'CY', label: 'Chypre', group: 'Europe' },
  { code: 'CZ', label: 'Tchéquie', group: 'Europe' },
  { code: 'DK', label: 'Danemark', group: 'Europe' },
  { code: 'EE', label: 'Estonie', group: 'Europe' },
  { code: 'FI', label: 'Finlande', group: 'Europe' },
  { code: 'FR', label: 'France', group: 'Europe' },
  { code: 'DE', label: 'Allemagne', group: 'Europe' },
  { code: 'GR', label: 'Grèce', group: 'Europe' },
  { code: 'HU', label: 'Hongrie', group: 'Europe' },
  { code: 'IS', label: 'Islande', group: 'Europe' },
  { code: 'IE', label: 'Irlande', group: 'Europe' },
  { code: 'IT', label: 'Italie', group: 'Europe' },
  { code: 'XK', label: 'Kosovo', group: 'Europe' },
  { code: 'LV', label: 'Lettonie', group: 'Europe' },
  { code: 'LI', label: 'Liechtenstein', group: 'Europe' },
  { code: 'LT', label: 'Lituanie', group: 'Europe' },
  { code: 'LU', label: 'Luxembourg', group: 'Europe' },
  { code: 'MT', label: 'Malte', group: 'Europe' },
  { code: 'MD', label: 'Moldavie', group: 'Europe' },
  { code: 'MC', label: 'Monaco', group: 'Europe' },
  { code: 'ME', label: 'Monténégro', group: 'Europe' },
  { code: 'NL', label: 'Pays-Bas', group: 'Europe' },
  { code: 'MK', label: 'Macédoine du Nord', group: 'Europe' },
  { code: 'NO', label: 'Norvège', group: 'Europe' },
  { code: 'PL', label: 'Pologne', group: 'Europe' },
  { code: 'PT', label: 'Portugal', group: 'Europe' },
  { code: 'RO', label: 'Roumanie', group: 'Europe' },
  { code: 'RU', label: 'Russie', group: 'Europe' },
  { code: 'SM', label: 'Saint-Marin', group: 'Europe' },
  { code: 'RS', label: 'Serbie', group: 'Europe' },
  { code: 'SK', label: 'Slovaquie', group: 'Europe' },
  { code: 'SI', label: 'Slovénie', group: 'Europe' },
  { code: 'ES', label: 'Espagne', group: 'Europe' },
  { code: 'SE', label: 'Suède', group: 'Europe' },
  { code: 'CH', label: 'Suisse', group: 'Europe' },
  { code: 'UA', label: 'Ukraine', group: 'Europe' },
  { code: 'GB', label: 'Royaume-Uni', group: 'Europe' },
  { code: 'VA', label: 'Vatican', group: 'Europe' },
];

/** Regroupe GEOCODING_COUNTRY_OPTIONS par continent pour l'affichage en <optgroup> — l'option
 *  "" (recherche mondiale) reste hors groupe, affichée seule en tête de liste. */
export function groupedCountryOptions() {
  const groups = new Map<string, { code: string; label: string }[]>();
  for (const opt of GEOCODING_COUNTRY_OPTIONS) {
    if (!opt.group) continue;
    if (!groups.has(opt.group)) groups.set(opt.group, []);
    groups.get(opt.group)!.push(opt);
  }
  return Array.from(groups.entries()).map(([group, options]) => ({ group, options }));
}

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

  worldOption = GEOCODING_COUNTRY_OPTIONS[0];
  countryGroups = groupedCountryOptions();

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
