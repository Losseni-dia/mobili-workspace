import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import {
  PartenaireService,
  PartnerDashboard,
  Station,
} from '../../../core/services/partners/partenaire.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { PartnerTicket, TicketService } from '../../../core/services/ticket/ticket.service';
import { ListPager } from '../../../core/utils/list-pager.util';
import { toLocalDateString } from '../../../core/utils/period-range.util';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, FormsModule],
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.scss'],
})
export class DashboardComponent implements OnInit {
  private partenaireService = inject(PartenaireService);
  private auth = inject(AuthService);
  private ticketService = inject(TicketService);

  /** Infos ticket (pas réservation agrégée) — un booking peut couvrir plusieurs sièges/tickets. */
  recentTickets = signal<PartnerTicket[]>([]);
  /** Pagination "Voir plus" — potentiellement tout le mois de tickets d'un coup. */
  recentTicketsPager = new ListPager(this.recentTickets);
  stations = signal<Station[]>([]);
  /** Dirigeant : filtre des KPI (backend `stationId` optionnel) */
  stationFilter: 'all' | number = 'all';

  /**
   * Vue d'ensemble scindée en deux blocs bien distincts pour ne plus jamais confondre un chiffre
   * "depuis toujours" avec un chiffre "de ce mois" (source du décalage remonté par l'utilisateur
   * entre le dashboard et les pages Tickets/Réservations) :
   * - `allTime` : totaux vie entière (GET /partenaire/dashboard/stats, sans filtre de période).
   * - `month`   : recalculé côté client à partir des tickets du mois en cours (même source que
   *   "Tickets vendus (mois)"), donc toujours aligné avec les pages Tickets/Réservations en "Mois".
   */
  allTime = signal({ activeTrips: 0, bookings: 0, revenueTotal: 0, revenueOnline: 0, revenueOffline: 0 });
  month = signal({ ticketsSold: 0, revenueTotal: 0, revenueOnline: 0, revenueOffline: 0 });
  isLoadingAllTime = signal(false);
  isLoadingMonth = signal(false);

  /** Libellé du mois en cours, ex. "septembre 2026" — affiché en tête du bloc mensuel. */
  currentMonthLabel = new Date().toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });

  isGareOnly = () => this.auth.hasRole('GARE');

  ngOnInit() {
    this.partenaireService.listStations().subscribe({
      next: (list) => {
        this.stations.set(list);
        this.loadStats();
      },
      error: () => this.loadStats(),
    });
  }

  onStationFilterChange() {
    this.loadStats();
  }

  private loadStats() {
    const sid: number | undefined =
      this.isGareOnly() || this.stationFilter === 'all' ? undefined : this.stationFilter;

    this.isLoadingAllTime.set(true);
    this.partenaireService.getDashboardStats(sid).subscribe({
      next: (data: PartnerDashboard) => {
        this.allTime.set({
          activeTrips: data.activeTripsCount,
          bookings: data.totalBookingsCount,
          revenueTotal: data.totalRevenue,
          revenueOnline: data.revenueOnline ?? 0,
          revenueOffline: data.revenueOffline ?? 0,
        });
        this.isLoadingAllTime.set(false);
      },
      error: (err) => {
        console.error('Erreur stats dashboard :', err);
        this.isLoadingAllTime.set(false);
      },
    });

    const now = new Date();
    const from = toLocalDateString(new Date(now.getFullYear(), now.getMonth(), 1));
    const to = toLocalDateString(new Date(now.getFullYear(), now.getMonth() + 1, 0));
    this.isLoadingMonth.set(true);
    this.ticketService.getPartnerTicketsInRange(from, to, sid).subscribe({
      next: (tickets) => {
        // Revenus du mois — recalculés à partir de CES MÊMES tickets (période + rattachement
        // à la date du voyage déjà appliqués côté backend), jamais depuis getDashboardStats
        // (all-time, sans filtre de période) : sinon "Revenus du mois" affichait en réalité le
        // revenu total, en décalage avec "Tickets vendus (mois)" et les pages Tickets/Réservations
        // filtrées sur "Mois" — c'est exactement le décalage remonté par l'utilisateur.
        const active = tickets.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ');
        const revenueOnline = active
          .filter((t) => t.bookingStatus === 'CONFIRMED')
          .reduce((sum, t) => sum + (t.grossAmount ?? t.amountPaid ?? 0), 0);
        const revenueOffline = active
          .filter((t) => t.bookingStatus === 'OFFLINE_SALE')
          .reduce((sum, t) => sum + (t.grossAmount ?? t.amountPaid ?? 0), 0);
        this.month.set({
          ticketsSold: tickets.length,
          revenueTotal: revenueOnline + revenueOffline,
          revenueOnline,
          revenueOffline,
        });
        // Infos ticket (pas réservation agrégée) : tri du plus récent au plus ancien.
        const sorted = [...tickets].sort(
          (a, b) => new Date(b.bookingDate).getTime() - new Date(a.bookingDate).getTime(),
        );
        this.recentTickets.set(sorted);
        this.recentTicketsPager.reset();
        this.isLoadingMonth.set(false);
      },
      error: () => {
        this.month.set({ ticketsSold: 0, revenueTotal: 0, revenueOnline: 0, revenueOffline: 0 });
        this.recentTickets.set([]);
        this.isLoadingMonth.set(false);
      },
    });
  }
}
