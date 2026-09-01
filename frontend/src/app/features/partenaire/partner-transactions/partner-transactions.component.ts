import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { BookingService, PartnerTransaction } from '../../../core/services/booking/booking.service';
import { PartenaireService, Station } from '../../../core/services/partners/partenaire.service';
import { exportToCsv } from '../../../core/utils/csv-export.util';
import { computePeriodRange, PeriodPreset, toLocalDateString } from '../../../core/utils/period-range.util';
import { ListPager } from '../../../core/utils/list-pager.util';

/**
 * Détail financier (frais Mobili/commission, net compagnie) par réservation payée — parité
 * mobilipro (« Transactions » compagnie), endpoint GET /bookings/partner/transactions/range
 * jamais consommé par aucune page web avant ce chantier.
 */
@Component({
  selector: 'app-partner-transactions',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './partner-transactions.component.html',
  styleUrl: './partner-transactions.component.scss',
})
export class PartnerTransactionsComponent implements OnInit {
  private bookingService = inject(BookingService);
  private partenaireService = inject(PartenaireService);

  transactions = signal<PartnerTransaction[]>([]);
  stations = signal<Station[]>([]);
  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  fromDate = signal('');
  toDate = signal('');
  search = signal('');
  stationFilter = signal<number | null>(null);
  activePeriod = signal<PeriodPreset | null>(null);
  /** Mode "Date précise" (une seule date, from=to) — distinct de "Intervalle" (from/to libres). */
  singleDateMode = signal(false);

  filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    if (!term) return this.transactions();
    return this.transactions().filter(
      (t) => (t.reference || '').toLowerCase().includes(term) || (t.route || '').toLowerCase().includes(term),
    );
  });

  totalCommission = computed(() => this.filtered().reduce((sum, t) => sum + (t.commissionTotal || 0), 0));
  totalCompanyNet = computed(() => this.filtered().reduce((sum, t) => sum + (t.companyNet || 0), 0));
  totalGross = computed(() => this.filtered().reduce((sum, t) => sum + (t.grossAmount || 0), 0));

  /** Pagination "Voir plus" — évite d'afficher toute la liste (potentiellement longue) d'un coup. */
  pager = new ListPager(this.filtered);

  /** Une entrée par date (en-tête) suivie de ses transactions — pour le regroupement par jour. */
  groupedRows = computed(() => {
    const out: Array<{ dateHeader?: string; row?: PartnerTransaction }> = [];
    let lastDay = '';
    for (const t of this.pager.visible()) {
      const day = (t.date || '').slice(0, 10);
      if (day !== lastDay) {
        out.push({ dateHeader: day });
        lastDay = day;
      }
      out.push({ row: t });
    }
    return out;
  });

  ngOnInit(): void {
    this.partenaireService.listStations().subscribe({
      next: (s) => this.stations.set(s),
      error: () => this.stations.set([]),
    });
    // Vue par défaut plus large qu'un simple "Mois" calendaire : la période filtre désormais
    // sur la date du VOYAGE (pas la date de réservation), donc une résa faite aujourd'hui pour
    // un trajet le mois prochain n'apparaissait plus du tout dans "Mois" — ici on couvre large
    // (30 j en arrière, 180 j en avant) pour que les réservations récentes restent visibles
    // avec leur commission dès qu'elles existent, quelle que soit la date de leur voyage.
    const now = new Date();
    const from = new Date(now);
    from.setDate(now.getDate() - 30);
    const to = new Date(now);
    to.setDate(now.getDate() + 180);
    this.activePeriod.set(null);
    this.singleDateMode.set(false);
    this.fromDate.set(toLocalDateString(from));
    this.toDate.set(toLocalDateString(to));
    this.load();
  }

  load(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.bookingService
      .getPartnerTransactionsInRange(this.fromDate() || undefined, this.toDate() || undefined, this.stationFilter() ?? undefined)
      .subscribe({
        next: (data) => {
          this.transactions.set(data || []);
          this.isLoading.set(false);
        },
        error: (err) => {
          console.error('Erreur chargement transactions partenaire', err);
          this.errorMessage.set('Impossible de charger les transactions pour le moment.');
          this.isLoading.set(false);
        },
      });
  }

  onStationFilterChange(raw: string): void {
    this.stationFilter.set(raw === '' ? null : Number(raw));
    this.pager.reset();
    this.load();
  }

  setPeriodPreset(preset: PeriodPreset): void {
    const { from, to } = computePeriodRange(preset);
    this.activePeriod.set(preset);
    this.fromDate.set(from);
    this.toDate.set(to);
    this.pager.reset();
    this.load();
  }

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
    const d = this.fromDate() || toLocalDateString(new Date());
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

  exportCsv(): void {
    exportToCsv(
      `transactions-compagnie-${new Date().toISOString().slice(0, 10)}`,
      this.filtered().map((t) => ({
        Référence: t.reference,
        Trajet: t.route,
        'Date résa': t.date,
        'Date départ': t.departureDateTime ?? '—',
        Statut: t.status,
        'Vente brute (FCFA)': t.grossAmount,
        'Commission (FCFA)': t.commissionTotal,
        'Net compagnie (FCFA)': t.companyNet,
      })),
    );
  }
}
