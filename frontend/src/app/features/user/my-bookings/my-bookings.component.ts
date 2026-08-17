import { Component, OnInit, OnDestroy, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';

import { AuthService } from '../../../core/services/auth/auth.service';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';
import { computePeriodRange, PeriodPreset } from '../../../core/utils/period-range.util';
import { bookingStatusLabel } from '../../../core/utils/booking-status-label.util';

type StatusFilter = 'ALL' | 'CONFIRMED' | 'PENDING' | 'CANCELLED';

@Component({
  selector: 'app-my-bookings',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './my-bookings.component.html',
  styleUrl: './my-bookings.component.scss',
})
export class MyBookingsComponent implements OnInit, OnDestroy {
  private bookingService = inject(BookingService);
  private authService = inject(AuthService);

  /** Rafraîchi toutes les 15s pour faire vivre le compte à rebours de paiement covoiturage. */
  private now = signal(Date.now());
  private tickHandle: ReturnType<typeof setInterval> | null = null;

  bookings = signal<BookingResponse[]>([]);
  isLoading = signal<boolean>(true);
  filter = signal<StatusFilter>('ALL');
  search = signal<string>('');

  /**
   * Filtre période — purement client-side (pas d'endpoint /user/{id}/range côté backend) :
   * toutes les réservations de l'utilisateur sont déjà chargées en un seul appel, on filtre
   * ensuite sur la date de création (`b.date`, repli sur `departureDateTime` si absente).
   */
  fromDate = signal('');
  toDate = signal('');
  activePeriod = signal<PeriodPreset | null>(null);
  /** Distinct de `activePeriod === null` : ici null veut aussi dire « aucun filtre » (pas de
   *  préset par défaut, contrairement aux listes admin/partenaire/gare). */
  customMode = signal(false);

  isCustomPeriod(): boolean {
    return this.customMode();
  }

  filtered = computed(() => {
    const raw = this.bookings();
    const f = this.filter();
    const q = this.search().trim().toLowerCase();
    const from = this.fromDate();
    const to = this.toDate();

    return raw
      .filter((b) => {
        if (f === 'ALL') return true;
        const s = (b.status || '').toUpperCase();
        if (f === 'CONFIRMED') return s === 'CONFIRMED' || s === 'PAID' || s === 'CONFIRME';
        if (f === 'PENDING') return s === 'PENDING' || s === 'WAITING' || s === 'EN_ATTENTE';
        if (f === 'CANCELLED') return s === 'CANCELLED' || s === 'ANNULE' || s === 'REFUSED';
        return true;
      })
      .filter((b) => {
        if (!from && !to) return true;
        const bookingDate = b.date || b.departureDateTime;
        if (!bookingDate) return true;
        const day = bookingDate.slice(0, 10);
        if (from && day < from) return false;
        if (to && day > to) return false;
        return true;
      })
      .filter((b) => {
        if (!q) return true;
        return (
          (b.reference || '').toLowerCase().includes(q) ||
          (b.departureCity || '').toLowerCase().includes(q) ||
          (b.arrivalCity || '').toLowerCase().includes(q) ||
          (b.boardingCity || '').toLowerCase().includes(q) ||
          (b.alightingCity || '').toLowerCase().includes(q)
        );
      })
      .sort((a, b) => {
        const ta = a.departureDateTime ? Date.parse(a.departureDateTime) : 0;
        const tb = b.departureDateTime ? Date.parse(b.departureDateTime) : 0;
        return tb - ta;
      });
  });

  setPeriodPreset(preset: PeriodPreset): void {
    const { from, to } = computePeriodRange(preset);
    this.activePeriod.set(preset);
    this.customMode.set(false);
    this.fromDate.set(from);
    this.toDate.set(to);
  }

  /** Bascule/reste en mode « Intervalle » : la modif d'une des deux dates repasse ici. */
  onManualDateChange(): void {
    this.activePeriod.set(null);
    this.customMode.set(true);
  }

  clearPeriod(): void {
    this.activePeriod.set(null);
    this.customMode.set(false);
    this.fromDate.set('');
    this.toDate.set('');
  }

  // ====== STATS ======
  countByStatus = computed(() => {
    const raw = this.bookings();
    const upper = (s: string | undefined) => (s || '').toUpperCase();
    return {
      all: raw.length,
      confirmed: raw.filter((b) => ['CONFIRMED', 'PAID', 'CONFIRME'].includes(upper(b.status))).length,
      pending: raw.filter((b) => ['PENDING', 'WAITING', 'EN_ATTENTE'].includes(upper(b.status))).length,
      cancelled: raw.filter((b) => ['CANCELLED', 'ANNULE', 'REFUSED'].includes(upper(b.status))).length,
    };
  });

  totalSpent = computed(() =>
    this.bookings().reduce((sum, b) => sum + this.displayAmount(b), 0),
  );

  /**
   * Montant à afficher pour une réservation dans « Mes réservations » :
   * `ticketsTotalAmount` (hors forfait client) — jamais `totalPrice`, qui l'inclut.
   * Retombe sur `totalPrice`/`amount` pour les réservations créées avant le forfait
   * client (`ticketsTotalAmount` absent, pas de recalcul rétroactif).
   */
  displayAmount(b: BookingResponse): number {
    const v = Number(b.ticketsTotalAmount ?? b.totalPrice ?? b.amount ?? 0);
    return Number.isNaN(v) ? 0 : v;
  }

  ngOnInit() {
    const userId = this.authService.currentUser()?.id;
    if (userId == null) {
      this.isLoading.set(false);
      return;
    }
    this.bookingService.getUserBookings(userId).subscribe({
      next: (data) => {
        this.bookings.set(data ?? []);
        this.isLoading.set(false);
      },
      error: () => {
        this.bookings.set([]);
        this.isLoading.set(false);
      },
    });
    this.tickHandle = setInterval(() => this.now.set(Date.now()), 15000);
  }

  ngOnDestroy() {
    if (this.tickHandle != null) clearInterval(this.tickHandle);
  }

  /**
   * Covoiturage accepté : fenêtre de paiement (~30 min, `paymentDeadline`). Aligné sur mobile
   * (paiement possible depuis « Mes réservations » une fois la demande acceptée par le
   * conducteur). `null` si non applicable ou délai expiré.
   */
  paymentCountdown(b: BookingResponse): string | null {
    if (!b.paymentDeadline) return null;
    const deadline = Date.parse(b.paymentDeadline);
    if (Number.isNaN(deadline)) return null;
    const remainingMs = deadline - this.now();
    if (remainingMs <= 0) return null;
    const totalSeconds = Math.floor(remainingMs / 1000);
    const mm = Math.floor(totalSeconds / 60);
    const ss = totalSeconds % 60;
    return `${mm}:${ss.toString().padStart(2, '0')}`;
  }

  setFilter(f: StatusFilter) { this.filter.set(f); }

  onSearch(ev: Event) {
    this.search.set((ev.target as HTMLInputElement).value);
  }

  statusClass(status: string | undefined): string {
    const s = (status || '').toUpperCase();
    if (['CONFIRMED', 'PAID', 'CONFIRME'].includes(s)) return 'active';
    if (['PENDING', 'WAITING', 'EN_ATTENTE'].includes(s)) return 'warn';
    if (['CANCELLED', 'ANNULE', 'REFUSED'].includes(s)) return 'blocked';
    return 'info';
  }

  statusLabel(status: string | undefined | null): string {
    return bookingStatusLabel(status);
  }
}
