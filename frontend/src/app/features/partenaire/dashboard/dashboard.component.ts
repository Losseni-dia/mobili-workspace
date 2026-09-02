import { Component, inject, OnInit, signal, WritableSignal } from '@angular/core';
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
import { TripService } from '../../../core/services/trip/trip.service';
import { ListPager } from '../../../core/utils/list-pager.util';
import { toLocalDateString } from '../../../core/utils/period-range.util';

/** Un bloc de KPI recalculé côté client pour une période donnée (mois/année en cours) — jamais
 *  une fenêtre glissante, toujours les vraies bornes civiles. Même shape que côté admin
 *  (admin-dashboard.ts), adaptée au périmètre partenaire (pas d'inscriptions user/partenaire ici). */
export interface PeriodStats {
  activeTrips: number;
  tripsWithSales: number;
  ticketsSold: number;
  ticketsSoldOnline: number;
  ticketsSoldOffline: number;
  revenueTotal: number;
  revenueOnline: number;
  revenueOffline: number;
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
};

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
  private tripService = inject(TripService);

  /** Infos ticket (pas réservation agrégée) — un booking peut couvrir plusieurs sièges/tickets. */
  recentTickets = signal<PartnerTicket[]>([]);
  /** Pagination "Voir plus" — potentiellement tout le mois de tickets d'un coup. */
  recentTicketsPager = new ListPager(this.recentTickets);
  stations = signal<Station[]>([]);
  /** Dirigeant : filtre des KPI (backend `stationId` optionnel) */
  stationFilter: 'all' | number = 'all';

  /**
   * Vue d'ensemble en trois blocs bien distincts pour ne plus jamais confondre un chiffre
   * "depuis toujours" avec un chiffre "de cette année" ou "de ce mois" (source du décalage
   * remonté par l'utilisateur entre le dashboard et les pages Tickets/Réservations) :
   * - `allTime` : totaux vie entière (GET /partenaire/dashboard/stats, sans filtre de période).
   * - `year`/`month` : recalculés côté client à partir des trajets/tickets de la période
   *   (mêmes bornes civiles que les pages Tickets/Réservations/Statistiques métier).
   */
  allTime = signal({
    activeTrips: 0,
    ticketsSold: 0,
    ticketsSoldOnline: 0,
    ticketsSoldOffline: 0,
    revenueTotal: 0,
    revenueOnline: 0,
    revenueOffline: 0,
  });
  isLoadingAllTime = signal(false);

  isLoadingYear = signal(false);
  year = signal<PeriodStats>({ ...EMPTY_PERIOD_STATS });

  isLoadingMonth = signal(false);
  month = signal<PeriodStats>({ ...EMPTY_PERIOD_STATS });

  /** Libellé de l'année en cours, ex. "2026". */
  currentYearLabel = String(new Date().getFullYear());
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

  private currentStationId(): number | undefined {
    return this.isGareOnly() || this.stationFilter === 'all' ? undefined : this.stationFilter;
  }

  private loadStats() {
    const sid = this.currentStationId();

    this.isLoadingAllTime.set(true);
    this.partenaireService.getDashboardStats(sid).subscribe({
      next: (data: PartnerDashboard) => {
        this.allTime.set({
          activeTrips: data.activeTripsCount,
          ticketsSold: (data.ticketsSoldOnline ?? 0) + (data.ticketsSoldOffline ?? 0),
          ticketsSoldOnline: data.ticketsSoldOnline ?? 0,
          ticketsSoldOffline: data.ticketsSoldOffline ?? 0,
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
    this.loadPeriodStats(
      {
        from: toLocalDateString(new Date(now.getFullYear(), 0, 1)),
        to: toLocalDateString(new Date(now.getFullYear(), 11, 31)),
      },
      this.year,
      this.isLoadingYear,
      sid,
    );
    this.loadPeriodStats(
      {
        from: toLocalDateString(new Date(now.getFullYear(), now.getMonth(), 1)),
        to: toLocalDateString(new Date(now.getFullYear(), now.getMonth() + 1, 0)),
      },
      this.month,
      this.isLoadingMonth,
      sid,
      // "Derniers tickets" reste alimenté par le mois uniquement, jamais l'année (liste bien
      // trop longue pour un panneau "récents").
      true,
    );
  }

  /** Recalcule un bloc PeriodStats pour [from, to] — factorisé entre "Cette année" et
   *  "Ce mois-ci", seule la plage (et fillRecentTickets) change. */
  private loadPeriodStats(
    { from, to }: { from: string; to: string },
    target: WritableSignal<PeriodStats>,
    loading: WritableSignal<boolean>,
    stationId: number | undefined,
    fillRecentTickets = false,
  ) {
    loading.set(true);

    this.tripService.getPartnerTripsInRange(from, to).subscribe({
      next: (trips) => {
        const activeTrips = trips.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ').length;
        target.update((m) => ({ ...m, activeTrips }));
      },
      error: () => target.update((m) => ({ ...m, activeTrips: 0 })),
    });

    this.ticketService.getPartnerTicketsInRange(from, to, stationId).subscribe({
      next: (tickets) => {
        // Revenus de la période — recalculés à partir de CES MÊMES tickets (période + rattachement
        // à la date du voyage déjà appliqués côté backend), jamais depuis getDashboardStats
        // (all-time, sans filtre de période) : sinon "Revenus" affichait en réalité le revenu
        // total, en décalage avec "Tickets vendus" et les pages Tickets/Réservations filtrées.
        const active = tickets.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ');
        const onlineTickets = active.filter((t) => t.bookingStatus === 'CONFIRMED');
        const offlineTickets = active.filter((t) => t.bookingStatus === 'OFFLINE_SALE');
        const revenueOnline = onlineTickets.reduce((sum, t) => sum + (t.grossAmount ?? t.amountPaid ?? 0), 0);
        const revenueOffline = offlineTickets.reduce((sum, t) => sum + (t.grossAmount ?? t.amountPaid ?? 0), 0);
        // Trajets distincts avec ≥1 ticket actif sur la période — même définition que "Trajets
        // avec ventes" de Stats métier (admin/partenaire), calculée ici depuis tripId (déjà
        // présent sur PartnerTicket), sans requête supplémentaire.
        const tripsWithSales = new Set(
          active.map((t) => t.tripId).filter((id): id is number => id != null),
        ).size;
        target.update((m) => ({
          ...m,
          tripsWithSales,
          ticketsSold: active.length,
          ticketsSoldOnline: onlineTickets.length,
          ticketsSoldOffline: offlineTickets.length,
          revenueTotal: revenueOnline + revenueOffline,
          revenueOnline,
          revenueOffline,
        }));
        if (fillRecentTickets) {
          // Infos ticket (pas réservation agrégée) : tri du plus récent au plus ancien.
          const sorted = [...tickets].sort(
            (a, b) => new Date(b.bookingDate).getTime() - new Date(a.bookingDate).getTime(),
          );
          this.recentTickets.set(sorted);
          this.recentTicketsPager.reset();
        }
        loading.set(false);
      },
      error: () => {
        target.update((m) => ({
          ...m,
          tripsWithSales: 0,
          ticketsSold: 0,
          ticketsSoldOnline: 0,
          ticketsSoldOffline: 0,
          revenueTotal: 0,
          revenueOnline: 0,
          revenueOffline: 0,
        }));
        if (fillRecentTickets) {
          this.recentTickets.set([]);
        }
        loading.set(false);
      },
    });
  }
}
