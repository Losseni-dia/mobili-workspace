import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService, AdminTicketListItem } from '../../../core/services/admin/admin.service';
import { computePeriodRange, PeriodPreset } from '../../../core/utils/period-range.util';
import { ListPager } from '../../../core/utils/list-pager.util';

type StatusFilter = 'CONFIRME' | 'ANNULE';

/** Confirmé = tout statut sauf ANNULÉ (même convention que mobilipro/gare). */
function isConfirmed(status: string | undefined): boolean {
  return (status || '').toUpperCase() !== 'ANNULÉ';
}

/**
 * Vue admin des tickets, toutes compagnies confondues — parité avec mobilipro
 * (tickets_list_page.dart), qui consomme le même endpoint GET /admin/stats/tickets/list.
 */
@Component({
  selector: 'app-admin-tickets',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-tickets.html',
  styleUrl: './admin-tickets.scss',
})
export class AdminTickets implements OnInit {
  private adminService = inject(AdminService);

  tickets = signal<AdminTicketListItem[]>([]);
  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  fromDate = signal('');
  toDate = signal('');
  search = signal('');
  statusFilter = signal<StatusFilter>('CONFIRME');
  activePeriod = signal<PeriodPreset | null>(null);
  /** Mode "Date précise" (une seule date, from=to) — distinct de "Intervalle" (from/to libres). */
  singleDateMode = signal(false);

  filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    const status = this.statusFilter();
    return this.tickets().filter((t) => {
      const matchSearch =
        !term ||
        t.ticketNumber.toLowerCase().includes(term) ||
        (t.passengerName || '').toLowerCase().includes(term) ||
        (t.partnerName || '').toLowerCase().includes(term) ||
        (t.route || '').toLowerCase().includes(term);
      const matchStatus = status === 'CONFIRME' ? isConfirmed(t.status) : !isConfirmed(t.status);
      return matchSearch && matchStatus;
    });
  });

  /** Toujours calculé sur la liste complète (période chargée), indépendamment du filtre actif. */
  confirmedAmount = computed(() =>
    this.tickets()
      .filter((t) => isConfirmed(t.status))
      .reduce((sum, t) => sum + (t.amountPaid || 0), 0),
  );

  /** Pagination "Voir plus" — évite d'afficher toute la liste (potentiellement longue) d'un coup. */
  pager = new ListPager(this.filtered);

  ngOnInit(): void {
    this.setPeriodPreset('month');
  }

  load(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.adminService.getTicketList(this.fromDate() || undefined, this.toDate() || undefined).subscribe({
      next: (data) => {
        this.tickets.set(data || []);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement tickets (admin)', err);
        this.errorMessage.set('Impossible de charger les tickets pour le moment.');
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
}
