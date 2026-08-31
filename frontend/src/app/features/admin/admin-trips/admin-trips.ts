import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService, AdminTripListItem } from '../../../core/services/admin/admin.service';
import { computePeriodRange, PeriodPreset } from '../../../core/utils/period-range.util';
import { ListPager } from '../../../core/utils/list-pager.util';

type StatusFilter = 'TOUS' | 'PROGRAMMÉ' | 'EN_COURS' | 'TERMINÉ' | 'ANNULÉ';

/**
 * Vue admin des trajets, toutes compagnies confondues — parité avec admin-tickets/admin-bookings,
 * consomme GET /admin/stats/trips/list (backend exclut déjà les brouillons DRAFT : seul le
 * catalogue publié doit être visible côté admin).
 */
@Component({
  selector: 'app-admin-trips',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-trips.html',
  styleUrl: './admin-trips.scss',
})
export class AdminTrips implements OnInit {
  private adminService = inject(AdminService);

  trips = signal<AdminTripListItem[]>([]);
  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  fromDate = signal('');
  toDate = signal('');
  search = signal('');
  statusFilter = signal<StatusFilter>('TOUS');
  activePeriod = signal<PeriodPreset | null>(null);
  /** Mode "Date précise" (une seule date, from=to) — distinct de "Intervalle" (from/to libres). */
  singleDateMode = signal(false);

  filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    const status = this.statusFilter();
    return this.trips().filter((t) => {
      const matchSearch =
        !term ||
        (t.route || '').toLowerCase().includes(term) ||
        (t.partnerName || '').toLowerCase().includes(term);
      const matchStatus = status === 'TOUS' ? true : t.status === status;
      return matchSearch && matchStatus;
    });
  });

  /** Pagination "Voir plus" — évite d'afficher toute la liste (potentiellement longue) d'un coup. */
  pager = new ListPager(this.filtered);

  ngOnInit(): void {
    this.setPeriodPreset('month');
  }

  load(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.adminService.getTripList(this.fromDate() || undefined, this.toDate() || undefined).subscribe({
      next: (data) => {
        this.trips.set(data || []);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement trajets (admin)', err);
        this.errorMessage.set('Impossible de charger les trajets pour le moment.');
        this.isLoading.set(false);
      },
    });
  }

  setStatusFilter(f: StatusFilter): void {
    this.statusFilter.set(f);
    this.pager.reset();
  }

  setPeriodPreset(preset: PeriodPreset): void {
    const { from, to } = computePeriodRange(preset);
    this.activePeriod.set(preset);
    this.fromDate.set(from);
    this.toDate.set(to);
    this.pager.reset();
    this.load();
  }

  /** Édition manuelle des dates : désactive le préset actif (l'intervalle n'y correspond plus). */
  onManualDateChange(): void {
    this.activePeriod.set(null);
    this.singleDateMode.set(false);
    this.pager.reset();
    this.load();
  }

  /** Bascule vers "Date précise" : préremplit avec la date déjà choisie, sinon aujourd'hui. */
  setSingleDateMode(): void {
    this.activePeriod.set(null);
    this.singleDateMode.set(true);
    const d = this.fromDate() || new Date().toISOString().slice(0, 10);
    this.fromDate.set(d);
    this.toDate.set(d);
    this.pager.reset();
    this.load();
  }

  onSingleDateChange(v: string): void {
    this.fromDate.set(v);
    this.toDate.set(v);
    this.pager.reset();
    this.load();
  }

  onSearch(v: string): void {
    this.search.set(v);
    this.pager.reset();
  }

  /** Étiquette lisible du statut (alignée sur trip-management statusLabel()). */
  statusLabel(status: string): string {
    switch (status) {
      case 'PROGRAMMÉ':
        return 'Programmé';
      case 'EN_COURS':
        return 'En cours';
      case 'TERMINÉ':
        return 'Terminé';
      case 'ANNULÉ':
        return 'Annulé';
      default:
        return status;
    }
  }

  /** Couleur de la pastille de statut (alignée sur trip-management statusPillClass()). */
  statusPillClass(status: string): string {
    switch (status) {
      case 'PROGRAMMÉ':
        return 'status-pill--programme';
      case 'EN_COURS':
        return 'status-pill--en-cours';
      case 'TERMINÉ':
        return 'status-pill--termine';
      case 'ANNULÉ':
        return 'status-pill--annule';
      default:
        return '';
    }
  }
}
