import { Component, OnInit, signal, inject, WritableSignal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AdminService, AdminStats } from '../../../core/services/admin/admin.service';
import { toLocalDateString } from '../../../core/utils/period-range.util';

/** Un bloc de KPI recalculé côté client pour une période donnée (mois ou année en cours) —
 * jamais une fenêtre glissante, toujours les vraies bornes civiles. */
export interface PeriodStats {
  activeTrips: number;
  tripsWithSales: number;
  ticketsSold: number;
  ticketsSoldOnline: number;
  ticketsSoldOffline: number;
  revenueTotal: number;
  revenueOnline: number;
  revenueOffline: number;
  newUsers: number;
  newPartners: number;
}

const EMPTY_PERIOD_STATS: PeriodStats = {
  activeTrips: 0,
  tripsWithSales: 0,
  ticketsSold: 0,
  ticketsSoldOnline: 0,
  ticketsSoldOffline: 0,
  revenueTotal: 0,
  revenueOnline: 0,
  revenueOffline: 0,
  newUsers: 0,
  newPartners: 0,
};

@Component({
  selector: 'app-admin-dashboard',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './admin-dashboard.html',
  styleUrl: './admin-dashboard.scss',
})
export class AdminDashboard implements OnInit {
  private adminService = inject(AdminService);

  stats = signal<AdminStats | null>(null);
  isLoading = signal(true);
  loadError = signal<string | null>(null);

  /**
   * "Cette année" / "Ce mois-ci" — même principe que les dashboards partenaire/gare : recalculé
   * côté client à partir des listes déjà filtrées sur la date du voyage (trajets/tickets/
   * transactions), pour ne jamais mélanger un chiffre all-time avec un chiffre de la période en
   * cours. Section "Cette année" ajoutée entre "Depuis toujours" et "Ce mois-ci" (2026-09-02) —
   * l'écart entre "Depuis toujours" et "Ce mois-ci" seul ne permettait pas de voir si un chiffre
   * mensuel bas était normal (début d'année) ou un vrai problème.
   */
  isLoadingYear = signal(false);
  year = signal<PeriodStats>({ ...EMPTY_PERIOD_STATS });

  isLoadingMonth = signal(false);
  month = signal<PeriodStats>({ ...EMPTY_PERIOD_STATS });

  /** Libellé de l'année en cours, ex. "2026". */
  currentYearLabel = String(new Date().getFullYear());
  /** Libellé du mois en cours, ex. "septembre 2026". */
  currentMonthLabel = new Date().toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });

  ngOnInit() {
    this.loadStats();
    this.loadPeriodStats(this.yearRange(), this.year, this.isLoadingYear);
    this.loadPeriodStats(this.monthRange(), this.month, this.isLoadingMonth);
  }

  // AUDIT-MOBILI.md §2.2 : échec de getAdminStats() auparavant totalement silencieux
  // (error: () => this.isLoading.set(false)) — aucun message affiché, l'admin voyait juste
  // un écran vide sans savoir si c'est "pas de données" ou "erreur réseau". Même pattern
  // (loadError signal + bouton réessayer) que admin-coupons.ts.
  loadStats() {
    this.isLoading.set(true);
    this.loadError.set(null);
    this.adminService.getAdminStats().subscribe({
      next: (data) => {
        this.stats.set(data);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement statistiques admin', err);
        this.loadError.set('Impossible de charger les statistiques. Réessaie.');
        this.isLoading.set(false);
      },
    });
  }

  private monthRange(): { from: string; to: string } {
    const now = new Date();
    return {
      from: toLocalDateString(new Date(now.getFullYear(), now.getMonth(), 1)),
      to: toLocalDateString(new Date(now.getFullYear(), now.getMonth() + 1, 0)),
    };
  }

  private yearRange(): { from: string; to: string } {
    const now = new Date();
    return {
      from: toLocalDateString(new Date(now.getFullYear(), 0, 1)),
      to: toLocalDateString(new Date(now.getFullYear(), 11, 31)),
    };
  }

  /** Recalcule un bloc PeriodStats pour [from, to] (bornes civiles) — factorisé entre "Cette
   * année" et "Ce mois-ci", même 3 appels (trajets/tickets/transactions), seule la plage change. */
  private loadPeriodStats(
    { from, to }: { from: string; to: string },
    target: WritableSignal<PeriodStats>,
    loading: WritableSignal<boolean>,
  ) {
    loading.set(true);

    this.adminService.getTripList(from, to).subscribe({
      next: (trips) => {
        const activeTrips = trips.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ').length;
        target.update((m) => ({ ...m, activeTrips }));
      },
      error: () => target.update((m) => ({ ...m, activeTrips: 0 })),
    });

    this.adminService.getTicketList(from, to).subscribe({
      next: (tickets) => {
        const active = tickets.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ');
        target.update((m) => ({
          ...m,
          ticketsSold: active.length,
          ticketsSoldOnline: active.filter((t) => t.bookingStatus === 'CONFIRMED').length,
          ticketsSoldOffline: active.filter((t) => t.bookingStatus === 'OFFLINE_SALE').length,
        }));
      },
      error: () =>
        target.update((m) => ({ ...m, ticketsSold: 0, ticketsSoldOnline: 0, ticketsSoldOffline: 0 })),
    });

    // Vente brute (totalPrice) — même base que revenueOnline/revenueOffline all-time, jamais
    // un recalcul par ticket actif (grossAmount n'existe pas côté admin) : cohérence entre les
    // blocs plutôt que des méthodes de calcul différentes.
    this.adminService.getTransactionList(from, to).subscribe({
      next: (transactions) => {
        const revenueOnline = transactions
          .filter((t) => (t.status || '').toUpperCase() === 'CONFIRMED')
          .reduce((sum, t) => sum + (t.totalPrice || 0), 0);
        const revenueOffline = transactions
          .filter((t) => (t.status || '').toUpperCase() === 'OFFLINE_SALE')
          .reduce((sum, t) => sum + (t.totalPrice || 0), 0);
        target.update((m) => ({
          ...m,
          revenueTotal: revenueOnline + revenueOffline,
          revenueOnline,
          revenueOffline,
        }));
        loading.set(false);
      },
      error: () => {
        target.update((m) => ({ ...m, revenueTotal: 0, revenueOnline: 0, revenueOffline: 0 }));
        loading.set(false);
      },
    });

    this.adminService.getRegistrationStats(from, to).subscribe({
      next: (data) => {
        const newUsers = data.history.reduce((sum, d) => sum + d.count, 0);
        target.update((m) => ({ ...m, newUsers }));
      },
      error: () => target.update((m) => ({ ...m, newUsers: 0 })),
    });

    this.adminService.getPartnerRegistrationStats(from, to).subscribe({
      next: (data) => {
        const newPartners = data.history.reduce((sum, d) => sum + d.count, 0);
        target.update((m) => ({ ...m, newPartners }));
      },
      error: () => target.update((m) => ({ ...m, newPartners: 0 })),
    });

    this.adminService.getTripsWithSalesCount(from, to).subscribe({
      next: (data) => target.update((m) => ({ ...m, tripsWithSales: data.count })),
      error: () => target.update((m) => ({ ...m, tripsWithSales: 0 })),
    });
  }
}
