import { Component, OnInit, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AdminService, AdminStats } from '../../../core/services/admin/admin.service';
import { toLocalDateString } from '../../../core/utils/period-range.util';

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
   * "Ce mois-ci" — même principe que les dashboards partenaire/gare : recalculé côté client à
   * partir des listes déjà filtrées sur la date du voyage (trajets/tickets/transactions), pour
   * ne jamais mélanger un chiffre all-time avec un chiffre du mois en cours.
   */
  isLoadingMonth = signal(false);
  month = signal({
    activeTrips: 0,
    ticketsSold: 0,
    ticketsSoldOnline: 0,
    ticketsSoldOffline: 0,
    revenueTotal: 0,
    revenueOnline: 0,
    revenueOffline: 0,
  });

  /** Libellé du mois en cours, ex. "septembre 2026". */
  currentMonthLabel = new Date().toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });

  ngOnInit() {
    this.loadStats();
    this.loadMonthStats();
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

  private loadMonthStats() {
    const now = new Date();
    const from = toLocalDateString(new Date(now.getFullYear(), now.getMonth(), 1));
    const to = toLocalDateString(new Date(now.getFullYear(), now.getMonth() + 1, 0));
    this.isLoadingMonth.set(true);

    this.adminService.getTripList(from, to).subscribe({
      next: (trips) => {
        const activeTrips = trips.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ').length;
        this.month.update((m) => ({ ...m, activeTrips }));
      },
      error: () => this.month.update((m) => ({ ...m, activeTrips: 0 })),
    });

    this.adminService.getTicketList(from, to).subscribe({
      next: (tickets) => {
        const active = tickets.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ');
        this.month.update((m) => ({
          ...m,
          ticketsSold: active.length,
          ticketsSoldOnline: active.filter((t) => t.bookingStatus === 'CONFIRMED').length,
          ticketsSoldOffline: active.filter((t) => t.bookingStatus === 'OFFLINE_SALE').length,
        }));
      },
      error: () =>
        this.month.update((m) => ({ ...m, ticketsSold: 0, ticketsSoldOnline: 0, ticketsSoldOffline: 0 })),
    });

    // Vente brute (totalPrice) — même base que revenueOnline/revenueOffline all-time, jamais
    // un recalcul par ticket actif (grossAmount n'existe pas côté admin) : cohérence entre les
    // deux blocs plutôt que deux méthodes de calcul différentes.
    this.adminService.getTransactionList(from, to).subscribe({
      next: (transactions) => {
        const revenueOnline = transactions
          .filter((t) => (t.status || '').toUpperCase() === 'CONFIRMED')
          .reduce((sum, t) => sum + (t.totalPrice || 0), 0);
        const revenueOffline = transactions
          .filter((t) => (t.status || '').toUpperCase() === 'OFFLINE_SALE')
          .reduce((sum, t) => sum + (t.totalPrice || 0), 0);
        this.month.update((m) => ({
          ...m,
          revenueTotal: revenueOnline + revenueOffline,
          revenueOnline,
          revenueOffline,
        }));
        this.isLoadingMonth.set(false);
      },
      error: () => {
        this.month.update((m) => ({ ...m, revenueTotal: 0, revenueOnline: 0, revenueOffline: 0 }));
        this.isLoadingMonth.set(false);
      },
    });
  }
}
