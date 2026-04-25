import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';

import { AuthService } from '../../../core/services/auth/auth.service';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';

type StatusFilter = 'ALL' | 'CONFIRMED' | 'PENDING' | 'CANCELLED';

@Component({
  selector: 'app-my-bookings',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './my-bookings.component.html',
  styleUrl: './my-bookings.component.scss',
})
export class MyBookingsComponent implements OnInit {
  private bookingService = inject(BookingService);
  private authService = inject(AuthService);

  bookings = signal<BookingResponse[]>([]);
  isLoading = signal<boolean>(true);
  filter = signal<StatusFilter>('ALL');
  search = signal<string>('');

  filtered = computed(() => {
    const raw = this.bookings();
    const f = this.filter();
    const q = this.search().trim().toLowerCase();

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
    this.bookings().reduce((sum, b) => {
      const v = Number(b.totalPrice ?? b.amount ?? 0);
      return sum + (Number.isNaN(v) ? 0 : v);
    }, 0),
  );

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
}
