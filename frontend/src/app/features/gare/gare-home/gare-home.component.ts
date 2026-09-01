import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { PartnerTicket, TicketService } from '../../../core/services/ticket/ticket.service';
import { TripService } from '../../../core/services/trip/trip.service';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';
import { PartenaireService, PartnerDashboard } from '../../../core/services/partners/partenaire.service';
import { ListPager } from '../../../core/utils/list-pager.util';
import { toLocalDateString } from '../../../core/utils/period-range.util';

/**
 * Dashboard gare — aligné sur `dashboard_gare_page.dart` (mobilipro) : revenu du mois (Via Mobili /
 * Au guichet), trajets actifs du mois, tickets vendus du mois, activité récente (tickets, pas
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

  // ====== Vue d'ensemble scindée en deux blocs (même structure que le dashboard partenaire) :
  // "Depuis toujours" (GET /partenaire/dashboard/stats, auto-scopé sur la gare connectée côté
  // backend via StationPrincipal) et "Ce mois-ci" (recalculé côté client à partir des mêmes
  // tickets/trajets que les pages Tickets/Trajets filtrées sur "Mois", pour rester aligné).
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

  isLoadingKpis = signal(false);
  activeTripsCount = signal<number | null>(null);
  ticketsSoldCount = signal<number | null>(null);
  ticketsSoldOnline = signal(0);
  ticketsSoldOffline = signal(0);
  revenueOnline = signal(0);
  revenueOffline = signal(0);
  revenueTotal = computed(() => this.revenueOnline() + this.revenueOffline());

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
    this.loadMonthlyKpis();
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

  private loadMonthlyKpis() {
    const { from, to } = this.monthRange();
    const stationId = this.stationId() ?? undefined;
    this.isLoadingKpis.set(true);

    this.tripService.getPartnerTripsInRange(from, to).subscribe({
      next: (trips) => {
        this.activeTripsCount.set(trips.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ').length);
      },
      error: () => this.activeTripsCount.set(null),
    });

    this.ticketService.getPartnerTicketsInRange(from, to, stationId).subscribe({
      next: (tickets) => {
        this.ticketsSoldCount.set(tickets.length);
        const active = tickets.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ');
        this.ticketsSoldOnline.set(active.filter((t) => t.bookingStatus === 'CONFIRMED').length);
        this.ticketsSoldOffline.set(active.filter((t) => t.bookingStatus === 'OFFLINE_SALE').length);
      },
      error: () => {
        this.ticketsSoldCount.set(null);
        this.ticketsSoldOnline.set(0);
        this.ticketsSoldOffline.set(0);
      },
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
        this.revenueOnline.set(online);
        this.revenueOffline.set(offline);
        this.isLoadingKpis.set(false);
      },
      error: () => {
        this.revenueOnline.set(0);
        this.revenueOffline.set(0);
        this.isLoadingKpis.set(false);
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
