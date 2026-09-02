import { Component, computed, inject, OnInit, signal, WritableSignal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { PartnerTicket, TicketService } from '../../../core/services/ticket/ticket.service';
import { TripService } from '../../../core/services/trip/trip.service';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';
import { PartenaireService, PartnerDashboard } from '../../../core/services/partners/partenaire.service';
import { ListPager } from '../../../core/utils/list-pager.util';
import { toLocalDateString } from '../../../core/utils/period-range.util';

/** Un bloc de KPI recalculé côté client pour une période donnée (mois/année en cours) — même
 *  shape que côté admin/partenaire (admin-dashboard.ts / dashboard.component.ts). */
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

/**
 * Dashboard gare — aligné sur `dashboard_gare_page.dart` (mobilipro) : revenu de la période (Via
 * Mobili / Au guichet), trajets actifs, tickets vendus, activité récente (tickets, pas
 * réservations agrégées — un booking peut couvrir plusieurs sièges/tickets, même convention que
 * le dashboard partenaire) paginée client. Combine plusieurs appels distincts, exactement comme
 * côté mobile (pas d'endpoint agrégé unique) — voir chaque méthode `load*` ci-dessous.
 */
@Component({
  selector: 'app-gare-home',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './gare-home.component.html',
  styleUrl: './gare-home.component.scss',
})
export class GareHomeComponent implements OnInit {
  auth = inject(AuthService);
  private ticketService = inject(TicketService);
  private tripService = inject(TripService);
  private bookingService = inject(BookingService);
  private partenaireService = inject(PartenaireService);

  user = computed(() => this.auth.currentUser());
  firstName = computed(() => this.user()?.firstname?.trim() || '');
  stationName = computed(() => this.user()?.stationName || 'Votre gare');
  stationId = computed(() => this.user()?.stationId);

  gareActionsLocked = computed(
    () => this.auth.hasRole('GARE') && this.auth.currentUser()?.gareOperationsEnabled === false,
  );

  // ====== Vue d'ensemble en trois blocs (même structure que le dashboard partenaire) :
  // "Depuis toujours" (GET /partenaire/dashboard/stats, auto-scopé sur la gare connectée côté
  // backend via StationPrincipal), "Cette année" et "Ce mois-ci" (recalculés côté client à
  // partir des mêmes tickets/trajets que les pages Tickets/Trajets filtrées sur la période).
  isLoadingAllTime = signal(false);
  allTime = signal({
    activeTrips: 0,
    ticketsSold: 0,
    ticketsSoldOnline: 0,
    ticketsSoldOffline: 0,
    revenueTotal: 0,
    revenueOnline: 0,
    revenueOffline: 0,
  });

  isLoadingYear = signal(false);
  year = signal<PeriodStats>({ ...EMPTY_PERIOD_STATS });

  isLoadingKpis = signal(false);
  month = signal<PeriodStats>({ ...EMPTY_PERIOD_STATS });

  /** Libellé de l'année en cours, ex. "2026". */
  currentYearLabel = String(new Date().getFullYear());
  /** Libellé du mois en cours, ex. "septembre 2026". */
  currentMonthLabel = new Date().toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });

  // ====== Activité récente (tickets, pagination "Voir plus") ======
  isLoadingRecent = signal(false);
  recentTickets = signal<PartnerTicket[]>([]);
  recentTicketsPager = new ListPager(this.recentTickets);

  ngOnInit(): void {
    this.auth.fetchUserProfile().subscribe({
      next: () => this.loadAll(),
      error: (e) => {
        console.error('Profil gare (accueil)', e);
        this.loadAll();
      },
    });
  }

  private loadAll() {
    if (this.gareActionsLocked()) return;
    this.loadAllTimeStats();
    const now = new Date();
    this.loadPeriodKpis(
      { from: toLocalDateString(new Date(now.getFullYear(), 0, 1)), to: toLocalDateString(new Date(now.getFullYear(), 11, 31)) },
      this.year,
      this.isLoadingYear,
    );
    this.loadPeriodKpis(this.monthRange(), this.month, this.isLoadingKpis);
    this.loadRecentTickets();
  }

  /** "Depuis toujours" — même endpoint que le dashboard partenaire, auto-scopé sur la gare
   *  connectée côté backend (StationPrincipal) : aucun stationId à passer explicitement. */
  private loadAllTimeStats() {
    this.isLoadingAllTime.set(true);
    this.partenaireService.getDashboardStats().subscribe({
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
        console.error('Erreur stats gare (depuis toujours)', err);
        this.isLoadingAllTime.set(false);
      },
    });
  }

  private monthRange(): { from: string; to: string } {
    const now = new Date();
    const first = new Date(now.getFullYear(), now.getMonth(), 1);
    const last = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    return { from: toLocalDateString(first), to: toLocalDateString(last) };
  }

  /** Recalcule un bloc PeriodStats pour [from, to] — factorisé entre "Cette année" et
   *  "Ce mois-ci", seule la plage change. */
  private loadPeriodKpis(
    { from, to }: { from: string; to: string },
    target: WritableSignal<PeriodStats>,
    loading: WritableSignal<boolean>,
  ) {
    const stationId = this.stationId() ?? undefined;
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
        const active = tickets.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ');
        // Trajets distincts avec ≥1 ticket actif sur la période — même définition que "Trajets
        // avec ventes" de Stats métier (admin/partenaire), calculée depuis tripId (déjà présent
        // sur PartnerTicket), sans requête supplémentaire.
        const tripsWithSales = new Set(
          active.map((t) => t.tripId).filter((id): id is number => id != null),
        ).size;
        target.update((m) => ({
          ...m,
          tripsWithSales,
          ticketsSold: tickets.length,
          ticketsSoldOnline: active.filter((t) => t.bookingStatus === 'CONFIRMED').length,
          ticketsSoldOffline: active.filter((t) => t.bookingStatus === 'OFFLINE_SALE').length,
        }));
      },
      error: () =>
        target.update((m) => ({ ...m, tripsWithSales: 0, ticketsSold: 0, ticketsSoldOnline: 0, ticketsSoldOffline: 0 })),
    });

    this.bookingService.getPartnerBookingsInRange(from, to).subscribe({
      next: (bookings) => {
        let online = 0;
        let offline = 0;
        for (const b of bookings) {
          const amount = this.grossAmount(b);
          if ((b.status || '').toUpperCase() === 'CONFIRMED') online += amount;
          else if ((b.status || '').toUpperCase() === 'OFFLINE_SALE') offline += amount;
        }
        target.update((m) => ({ ...m, revenueOnline: online, revenueOffline: offline, revenueTotal: online + offline }));
        loading.set(false);
      },
      error: () => {
        target.update((m) => ({ ...m, revenueOnline: 0, revenueOffline: 0, revenueTotal: 0 }));
        loading.set(false);
      },
    });
  }

  /**
   * Vente brute réelle (hors forfait client). `amount` (Booking.getGrossAmount(), backend) est
   * TOUJOURS recalculé en direct à partir des tickets encore actifs — priorité absolue sur
   * `ticketsTotalAmount`, qui est figé à la création et ne bouge plus si un ticket est annulé
   * individuellement ensuite (montant resté faux en production après une annulation partielle).
   * `ticketsTotalAmount + luggageFee` ne sert plus que de repli pour les réservations
   * antérieures au forfait client, où `amount` peut être absent.
   */
  private grossAmount(b: BookingResponse): number {
    if (b.amount != null) return b.amount;
    if (b.ticketsTotalAmount != null) return b.ticketsTotalAmount + (b.luggageFee || 0);
    return b.totalPrice ?? 0;
  }

  private loadRecentTickets() {
    this.isLoadingRecent.set(true);
    const { from, to } = this.monthRange();
    this.ticketService.getPartnerTicketsInRange(from, to, this.stationId() ?? undefined).subscribe({
      next: (tickets) => {
        // Infos ticket (pas réservation agrégée) : tri du plus récent au plus ancien.
        const sorted = [...tickets].sort(
          (a, b) => new Date(b.bookingDate).getTime() - new Date(a.bookingDate).getTime(),
        );
        this.recentTickets.set(sorted);
        this.recentTicketsPager.reset();
        this.isLoadingRecent.set(false);
      },
      error: () => {
        this.recentTickets.set([]);
        this.isLoadingRecent.set(false);
      },
    });
  }
}
