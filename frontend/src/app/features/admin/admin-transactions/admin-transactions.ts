import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService, AdminTransaction } from '../../../core/services/admin/admin.service';
import { computePeriodRange, PeriodPreset } from '../../../core/utils/period-range.util';
import { ListPager } from '../../../core/utils/list-pager.util';

/**
 * Page Transactions — frais Mobili (forfait), commission prélevée et net compagnie, par
 * réservation payée (CONFIRMED/OFFLINE_SALE). Le backend calcule et stocke ces montants
 * depuis le chantier forfait/commission, mais rien ne les relisait nulle part côté admin
 * avant cette page (confirmé par audit) — même donnée déjà exposée côté mobilipro
 * (admin_transactions_page.dart), consomme GET /admin/stats/transactions/list.
 */
@Component({
  selector: 'app-admin-transactions',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-transactions.html',
  styleUrl: './admin-transactions.scss',
})
export class AdminTransactions implements OnInit {
  private adminService = inject(AdminService);

  transactions = signal<AdminTransaction[]>([]);
  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  fromDate = signal('');
  toDate = signal('');
  search = signal('');
  activePeriod = signal<PeriodPreset | null>(null);
  /** Mode "Date précise" (une seule date, from=to) — distinct de "Intervalle" (from/to libres). */
  singleDateMode = signal(false);

  /** Filtre société, puis gare (dépendante de la société sélectionnée). */
  companyFilter = signal<number | 'all'>('all');
  stationFilter = signal<number | 'all'>('all');

  /** Liste distincte des sociétés présentes dans la période chargée (client-side, pas de nouvel appel). */
  companies = computed(() => {
    const map = new Map<number, string>();
    for (const t of this.transactions()) {
      if (t.companyId != null) map.set(t.companyId, t.companyName);
    }
    return [...map.entries()]
      .map(([id, name]) => ({ id, name }))
      .sort((a, b) => a.name.localeCompare(b.name));
  });

  /** Gares de la société sélectionnée uniquement — vide si "Toutes les sociétés". */
  stations = computed(() => {
    const company = this.companyFilter();
    if (company === 'all') return [];
    const map = new Map<number, string>();
    for (const t of this.transactions()) {
      if (t.companyId === company && t.stationId != null) map.set(t.stationId, t.stationName);
    }
    return [...map.entries()]
      .map(([id, name]) => ({ id, name }))
      .sort((a, b) => a.name.localeCompare(b.name));
  });

  filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    const company = this.companyFilter();
    const station = this.stationFilter();
    return this.transactions().filter((t) => {
      const matchSearch =
        !term ||
        (t.reference || '').toLowerCase().includes(term) ||
        (t.customerName || '').toLowerCase().includes(term) ||
        (t.companyName || '').toLowerCase().includes(term);
      const matchCompany = company === 'all' || t.companyId === company;
      const matchStation = station === 'all' || t.stationId === station;
      return matchSearch && matchCompany && matchStation;
    });
  });

  /** Une entrée par date (en-tête) suivie de ses transactions — pour le regroupement par jour. */
  groupedRows = computed(() => {
    const out: Array<{ dateHeader?: string; row?: AdminTransaction }> = [];
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

  // Suivent le filtre société/gare/recherche actif (pas juste la période) — cohérent avec ce
  // que la liste affiche réellement en dessous.
  totalServiceFee = computed(() => this.filtered().reduce((sum, t) => sum + (t.serviceFee || 0), 0));
  totalCommission = computed(() => this.filtered().reduce((sum, t) => sum + (t.commissionTotal || 0), 0));
  totalCompanyNet = computed(() => this.filtered().reduce((sum, t) => sum + (t.companyNet || 0), 0));
  totalRevenue = computed(() => this.filtered().reduce((sum, t) => sum + (t.totalPrice || 0), 0));

  /** Pagination "Voir plus" — évite d'afficher toute la liste (potentiellement longue) d'un coup. */
  pager = new ListPager(this.filtered);

  ngOnInit(): void {
    // Vue par défaut plus large qu'un simple "Mois" calendaire : la période filtre désormais
    // sur la date du VOYAGE (pas la date de réservation), donc une résa faite aujourd'hui pour
    // un trajet le mois prochain n'apparaissait plus du tout dans "Mois" — ici on couvre large
    // (30 j en arrière, 180 j en avant) pour que les réservations récentes restent visibles
    // avec leur commission dès qu'elles existent, quelle que soit la date de leur voyage.
    const iso = (d: Date) => d.toISOString().slice(0, 10);
    const now = new Date();
    const from = new Date(now);
    from.setDate(now.getDate() - 30);
    const to = new Date(now);
    to.setDate(now.getDate() + 180);
    this.activePeriod.set(null);
    this.singleDateMode.set(false);
    this.fromDate.set(iso(from));
    this.toDate.set(iso(to));
    this.load();
  }

  load(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.adminService.getTransactionList(this.fromDate() || undefined, this.toDate() || undefined).subscribe({
      next: (data) => {
        this.transactions.set(data || []);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement transactions (admin)', err);
        this.errorMessage.set('Impossible de charger les transactions pour le moment.');
        this.isLoading.set(false);
      },
    });
  }

  setPeriodPreset(preset: PeriodPreset): void {
    const { from, to } = computePeriodRange(preset);
    this.activePeriod.set(preset);
    this.fromDate.set(from);
    this.toDate.set(to);
    this.companyFilter.set('all');
    this.stationFilter.set('all');
    this.pager.reset();
    this.load();
  }

  onManualDateChange(): void {
    this.activePeriod.set(null);
    this.singleDateMode.set(false);
    this.companyFilter.set('all');
    this.stationFilter.set('all');
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
    this.companyFilter.set('all');
    this.stationFilter.set('all');
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

  onCompanyFilterChange(raw: string): void {
    this.companyFilter.set(raw === 'all' ? 'all' : Number(raw));
    // La gare dépend de la société — un choix précédent n'a plus de sens si on change de société.
    this.stationFilter.set('all');
    this.pager.reset();
  }

  onStationFilterChange(raw: string): void {
    this.stationFilter.set(raw === 'all' ? 'all' : Number(raw));
    this.pager.reset();
  }
}
