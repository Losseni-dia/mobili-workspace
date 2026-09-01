import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PartnerTicket, TicketService } from '../../../core/services/ticket/ticket.service';
import { PartenaireService, Station } from '../../../core/services/partners/partenaire.service';
import { exportToCsv } from '../../../core/utils/csv-export.util';
import { computePeriodRange, PeriodPreset, toLocalDateString } from '../../../core/utils/period-range.util';
import { ListPager } from '../../../core/utils/list-pager.util';

type TicketStatusFilter = 'CONFIRME' | 'ANNULE' | 'TOUS';

/** Confirmé = tout statut sauf ANNULÉ (même convention que gare-tickets/mobilipro). */
function isConfirmedTicket(status: string | undefined): boolean {
  return (status || '').toUpperCase() !== 'ANNULÉ';
}

/**
 * Vue « tickets » côté partenaire (toutes gares de la compagnie confondues) — endpoint déjà
 * utilisé par gare-tickets (scope station unique), jamais exposé sans filtre station côté
 * dirigeant. Parité mobilipro (« Tickets vendus » compagnie).
 */
@Component({
  selector: 'app-partner-tickets',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './partner-tickets.component.html',
  styleUrl: './partner-tickets.component.scss',
})
export class PartnerTicketsComponent implements OnInit {
  private ticketService = inject(TicketService);
  private partenaireService = inject(PartenaireService);

  tickets = signal<PartnerTicket[]>([]);
  stations = signal<Station[]>([]);
  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  search = signal('');
  statusFilter = signal<TicketStatusFilter>('CONFIRME');
  stationFilter = signal<number | null>(null);
  fromDate = signal('');
  toDate = signal('');
  activePeriod = signal<PeriodPreset | null>(null);
  /** Mode "Date précise" (une seule date, from=to) — distinct de "Intervalle" (from/to libres). */
  singleDateMode = signal(false);

  filteredTickets = computed(() => {
    const term = this.search().trim().toLowerCase();
    const status = this.statusFilter();
    return this.tickets().filter((t) => {
      const matchSearch =
        !term ||
        t.ticketNumber.toLowerCase().includes(term) ||
        (t.passengerName || '').toLowerCase().includes(term) ||
        (t.route || '').toLowerCase().includes(term);
      const matchStatus =
        status === 'TOUS' ? true : status === 'CONFIRME' ? isConfirmedTicket(t.status) : !isConfirmedTicket(t.status);
      return matchSearch && matchStatus;
    });
  });

  /** Toujours calculé sur tous les tickets chargés, indépendamment du filtre de statut actif. */
  confirmedAmount = computed(() =>
    this.tickets()
      .filter((t) => isConfirmedTicket(t.status))
      .reduce((sum, t) => sum + (t.grossAmount ?? t.amountPaid ?? 0), 0),
  );

  /** Pagination "Voir plus" — évite d'afficher toute la liste (potentiellement longue) d'un coup. */
  pager = new ListPager(this.filteredTickets);

  ngOnInit(): void {
    this.partenaireService.listStations().subscribe({
      next: (s) => this.stations.set(s),
      error: () => this.stations.set([]),
    });
    this.setPeriodPreset('month');
  }

  loadTickets(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.ticketService
      .getPartnerTicketsInRange(this.fromDate() || undefined, this.toDate() || undefined, this.stationFilter() ?? undefined)
      .subscribe({
        next: (data) => {
          this.tickets.set(data || []);
          this.isLoading.set(false);
        },
        error: (err) => {
          console.error('Erreur chargement tickets partenaire', err);
          this.errorMessage.set('Impossible de charger les tickets pour le moment.');
          this.isLoading.set(false);
        },
      });
  }

  setStatusFilter(f: TicketStatusFilter): void {
    this.statusFilter.set(f);
    this.pager.reset();
  }

  onStationFilterChange(raw: string): void {
    this.stationFilter.set(raw === '' ? null : Number(raw));
    this.pager.reset();
    this.loadTickets();
  }

  setPeriodPreset(preset: PeriodPreset): void {
    const { from, to } = computePeriodRange(preset);
    this.activePeriod.set(preset);
    this.fromDate.set(from);
    this.toDate.set(to);
    this.pager.reset();
    this.loadTickets();
  }

  onManualDateChange(): void {
    this.activePeriod.set(null);
    this.singleDateMode.set(false);
    this.pager.reset();
    this.loadTickets();
  }

  /** Bascule vers "Date précise" : préremplit avec la date déjà choisie, sinon aujourd'hui. */
  setSingleDateMode(): void {
    this.activePeriod.set(null);
    this.singleDateMode.set(true);
    const d = this.fromDate() || toLocalDateString(new Date());
    this.fromDate.set(d);
    this.toDate.set(d);
    this.pager.reset();
    this.loadTickets();
  }

  onSingleDateChange(v: string): void {
    this.fromDate.set(v);
    this.toDate.set(v);
    this.pager.reset();
    this.loadTickets();
  }

  onSearch(v: string): void {
    this.search.set(v);
    this.pager.reset();
  }

  displayAmount(t: PartnerTicket): number {
    return t.grossAmount ?? t.amountPaid ?? 0;
  }

  exportCsv(): void {
    exportToCsv(
      `tickets-compagnie-${new Date().toISOString().slice(0, 10)}`,
      this.filteredTickets().map((t) => ({
        'N° ticket': t.ticketNumber,
        Passager: t.passengerName,
        Trajet: t.route,
        Gare: t.stationName,
        'Date résa': t.bookingDate,
        'Date départ': t.departureDateTime ?? '—',
        Siège: t.seatNumber,
        Statut: t.status,
        Scanné: t.scanned ? 'Oui' : 'Non',
        'Montant (FCFA)': this.displayAmount(t),
      })),
    );
  }
}
