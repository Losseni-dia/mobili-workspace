import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';

import { AuthService } from '../../../core/services/auth/auth.service';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './profile.component.html',
  styleUrls: ['./profile.component.scss'],
})
export class ProfileComponent implements OnInit {
  authService = inject(AuthService);
  private bookingService = inject(BookingService);

  bookings = signal<BookingResponse[]>([]);
  isLoadingBookings = signal<boolean>(true);

  // ====== STATS ======
  totalBookings = computed(() => this.bookings().length);

  totalSeats = computed(() =>
    this.bookings().reduce((sum, b) => sum + (Number(b.numberOfSeats) || 0), 0),
  );

  totalSpent = computed(() =>
    this.bookings().reduce((sum, b) => {
      const value = Number(b.totalPrice ?? b.amount ?? 0);
      return sum + (Number.isNaN(value) ? 0 : value);
    }, 0),
  );

  upcomingBookings = computed(() => {
    const now = Date.now();
    return this.bookings()
      .filter((b) => {
        const t = b.departureDateTime ? Date.parse(b.departureDateTime) : NaN;
        return !Number.isNaN(t) && t >= now;
      })
      .sort((a, b) => Date.parse(a.departureDateTime) - Date.parse(b.departureDateTime))
      .slice(0, 3);
  });

  recentBookings = computed(() =>
    [...this.bookings()]
      .sort((a, b) => {
        const ta = a.bookingDate ? Date.parse(a.bookingDate) : 0;
        const tb = b.bookingDate ? Date.parse(b.bookingDate) : 0;
        return tb - ta;
      })
      .slice(0, 4),
  );

  ngOnInit(): void {
    if (this.authService.currentUser()) {
      this.authService.fetchUserProfile().subscribe({
        error: (err) => console.error('Erreur de synchronisation du profil', err),
      });
    }

    const userId = this.authService.currentUser()?.id;
    if (userId != null) {
      this.bookingService.getUserBookings(userId).subscribe({
        next: (data) => {
          this.bookings.set(data ?? []);
          this.isLoadingBookings.set(false);
        },
        error: () => {
          this.bookings.set([]);
          this.isLoadingBookings.set(false);
        },
      });
    } else {
      this.isLoadingBookings.set(false);
    }
  }

  statusClass(status: string | undefined): string {
    if (!status) return 'info';
    const s = status.toUpperCase();
    if (s === 'CONFIRMED' || s === 'CONFIRME' || s === 'PAID') return 'active';
    if (s === 'PENDING' || s === 'EN_ATTENTE' || s === 'WAITING') return 'warn';
    if (s === 'CANCELLED' || s === 'ANNULE' || s === 'REFUSED') return 'blocked';
    return 'info';
  }
}
