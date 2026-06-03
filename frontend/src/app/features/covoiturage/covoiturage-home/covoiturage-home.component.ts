import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { Trip, TripService } from '../../../core/services/trip/trip.service';
import { BookingResponse } from '../../../core/services/booking/booking.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { formatVehicleTypeLabel } from '../../../core/constants/vehicle-types';
import { MobiliSecureUploadImgComponent } from '../../../shared/upload/mobili-secure-upload-img.component';

@Component({
  selector: 'app-covoiturage-home',
  standalone: true,
  imports: [CommonModule, RouterLink, MobiliSecureUploadImgComponent],
  templateUrl: './covoiturage-home.component.html',
  styleUrl: './covoiturage-home.component.scss',
})
export class CovoiturageHomeComponent implements OnInit {
  auth = inject(AuthService);
  private readonly tripService = inject(TripService);
  private readonly notify = inject(NotificationService);

  u = computed(() => this.auth.currentUser());
  myTrips = signal<Trip[] | null>(null);
  loadingTrips = signal(false);

  /** tripId → liste de réservations (null = pas encore chargé, [] = aucune) */
  bookingsByTrip = signal<Map<number, BookingResponse[] | null>>(new Map());
  loadingBookings = signal<Set<number>>(new Set());

  formatVehicleType = formatVehicleTypeLabel;

  kycStatusLabel(s: string | null | undefined): string {
    if (!s) return '—';
    const m: Record<string, string> = {
      NONE: 'Non transmis',
      PENDING: 'En attente de validation',
      APPROVED: 'Validé',
      REJECTED: 'Refusé',
      EXPIRED: 'CNI expirée',
    };
    return m[s] ?? s;
  }

  bookingStatusLabel(s: string): string {
    const m: Record<string, string> = {
      PENDING: 'En attente',
      CONFIRMED: 'Confirmée',
      CANCELLED: 'Annulée',
      COMPLETED: 'Terminée',
      OFFLINE_SALE: 'Vente directe',
    };
    return m[s] ?? s;
  }

  ngOnInit(): void {
    this.loadTrips();
    this.auth.fetchUserProfile().subscribe({ error: () => {} });
  }

  loadTrips() {
    this.loadingTrips.set(true);
    this.tripService.getCovoiturageSoloMyTrips().subscribe({
      next: (list) => {
        this.myTrips.set(list);
        this.loadingTrips.set(false);
      },
      error: () => {
        this.myTrips.set([]);
        this.loadingTrips.set(false);
      },
    });
  }

  tripBookings(tripId: number): BookingResponse[] | null {
    return this.bookingsByTrip().get(tripId) ?? null;
  }

  isLoadingBookings(tripId: number): boolean {
    return this.loadingBookings().has(tripId);
  }

  toggleBookings(tripId: number) {
    const map = new Map(this.bookingsByTrip());
    if (map.has(tripId)) {
      map.delete(tripId);
      this.bookingsByTrip.set(map);
      return;
    }
    const loading = new Set(this.loadingBookings());
    loading.add(tripId);
    this.loadingBookings.set(loading);
    this.tripService.getCovoiturageTripBookings(tripId).subscribe({
      next: (list) => {
        const m = new Map(this.bookingsByTrip());
        m.set(tripId, list);
        this.bookingsByTrip.set(m);
        const l = new Set(this.loadingBookings());
        l.delete(tripId);
        this.loadingBookings.set(l);
      },
      error: () => {
        const m = new Map(this.bookingsByTrip());
        m.set(tripId, []);
        this.bookingsByTrip.set(m);
        const l = new Set(this.loadingBookings());
        l.delete(tripId);
        this.loadingBookings.set(l);
      },
    });
  }

  removeTrip(id: number) {
    if (!confirm('Retirer ce voyage publié ?')) return;
    this.tripService.deleteCovoiturageSoloTrip(id).subscribe({
      next: () => {
        this.notify.show('Voyage supprimé.', 'success');
        this.loadTrips();
      },
      error: (e) => this.notify.show(e?.error?.message || 'Suppression impossible', 'error'),
    });
  }
}

