import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { TicketService } from '../../../core/services/ticket/ticket.service';
import { TripService } from '../../../core/services/trip/trip.service';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';
import {
  PartenaireService,
  PartnerDashboard,
} from '../../../core/services/partners/partenaire.service';

/**
 * Dashboard gare — aligné sur `dashboard_gare_page.dart` (mobilipro) : revenu du mois (Via Mobili /
 * Au guichet), trajets actifs du mois, tickets vendus du mois, réservations récentes paginées
 * client (+10). Combine 4 appels distincts, exactement comme côté mobile (pas d'endpoint agrégé
 * unique) — voir chaque méthode `load*` ci-dessous.
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

  // ====== KPI du mois ======
  isLoadingKpis = signal(false);
  activeTripsCount = signal<number | null>(null);
  ticketsSoldCount = signal<number | null>(null);
  revenueOnline = signal(0);
  revenueOffline = signal(0);
  revenueTotal = computed(() => this.revenueOnline() + this.revenueOffline());

  // ====== Réservations récentes (pagination client +10, comme mobile) ======
  isLoadingRecent = signal(false);
  recentBookings = signal<PartnerDashboard['recentBookings']>([]);
  recentVisibleCount = signal(10);
  visibleRecentBookings = computed(() => this.recentBookings().slice(0, this.recentVisibleCount()));
  hasMoreRecent = computed(() => this.recentVisibleCount() < this.recentBookings().length);

  showMoreRecent() {
    this.recentVisibleCount.update((n) => n + 10);
  }

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
    this.loadRecentBookings();
  }

  private monthRange(): { from: string; to: string } {
    const now = new Date();
    const iso = (d: Date) => d.toISOString().slice(0, 10);
    const first = new Date(now.getFullYear(), now.getMonth(), 1);
    const last = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    return { from: iso(first), to: iso(last) };
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

  /** Vente brute réelle (hors forfait client) — jamais `totalPrice`/`amount` seuls si `ticketsTotalAmount` existe. */
  private grossAmount(b: BookingResponse): number {
    if (b.ticketsTotalAmount != null) return b.ticketsTotalAmount + (b.luggageFee || 0);
    return b.amount ?? b.totalPrice ?? 0;
  }

  private loadRecentBookings() {
    this.isLoadingRecent.set(true);
    this.recentVisibleCount.set(10);
    this.partenaireService.getDashboardStats(this.stationId() ?? null).subscribe({
      next: (stats) => {
        this.recentBookings.set(stats.recentBookings || []);
        this.isLoadingRecent.set(false);
      },
      error: () => {
        this.recentBookings.set([]);
        this.isLoadingRecent.set(false);
      },
    });
  }
}
