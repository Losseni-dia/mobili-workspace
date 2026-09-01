import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { PartnerTicket, TicketService } from '../../../core/services/ticket/ticket.service';
import { TripService } from '../../../core/services/trip/trip.service';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';
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

  user = computed(() => this.auth.currentUser());
  firstName = computed(() => this.user()?.firstname?.trim() || '');
  stationName = computed(() => this.user()?.stationName || 'Votre gare');
  stationId = computed(() => this.user()?.stationId);

  gareActionsLocked = computed(
    () => this.auth.hasRole('GARE') && this.auth.currentUser()?.gareOperationsEnabled === false,
  );

  // ====== KPI du mois ======
  isLoadingKpis = signal(false);
  activeTripsCount = signal<number | null>(null);
  ticketsSoldCount = signal<number | null>(null);
  revenueOnline = signal(0);
  revenueOffline = signal(0);
  revenueTotal = computed(() => this.revenueOnline() + this.revenueOffline());

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
    this.loadMonthlyKpis();
    this.loadRecentTickets();
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
      next: (tickets) => this.ticketsSoldCount.set(tickets.length),
      error: () => this.ticketsSoldCount.set(null),
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
