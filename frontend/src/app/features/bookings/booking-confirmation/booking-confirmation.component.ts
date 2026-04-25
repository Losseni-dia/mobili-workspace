import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { buildTripCityLabels } from '../../../core/utils/trip-city-labels.util';

@Component({
  selector: 'app-booking-confirmation',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './booking-confirmation.component.html',
  styleUrl: './booking-confirmation.component.scss',
})
export class BookingConfirmationComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private bookingService = inject(BookingService);
  private notificationService = inject(NotificationService);

  booking = signal<BookingResponse | null>(null);
  isProcessing = signal(false);

  /** Label de la ville d'embarquement (fallback calculé si manquant côté API). */
  boardingLabel = computed(() => {
    const b = this.booking();
    if (!b) return '';
    if (b.boardingCity) return b.boardingCity;
    const labels = buildTripCityLabels(b.departureCity, b.arrivalCity, b.moreInfo ?? '');
    const idx = b.boardingStopIndex ?? 0;
    return labels[idx] ?? b.departureCity;
  });

  alightingLabel = computed(() => {
    const b = this.booking();
    if (!b) return '';
    if (b.alightingCity) return b.alightingCity;
    const labels = buildTripCityLabels(b.departureCity, b.arrivalCity, b.moreInfo ?? '');
    const idx = b.alightingStopIndex ?? Math.max(0, labels.length - 1);
    return labels[idx] ?? b.arrivalCity;
  });

  /** Liste ordonnée des passagers + siège associé. */
  passengerLines = computed<{ name: string; seat: string }[]>(() => {
    const b = this.booking();
    if (!b) return [];
    const names = [...(b.passengerNames ?? [])].sort();
    const seats = [...(b.seatNumbers ?? [])].sort();
    const rows: { name: string; seat: string }[] = [];
    const max = Math.max(names.length, seats.length);
    for (let i = 0; i < max; i++) {
      rows.push({ name: names[i] ?? '—', seat: seats[i] ?? '—' });
    }
    return rows;
  });

  unitPrice = computed(() => {
    const b = this.booking();
    if (!b) return 0;
    if (b.pricePerSeat != null && !Number.isNaN(Number(b.pricePerSeat))) {
      return Number(b.pricePerSeat);
    }
    const total = Number(b.totalPrice ?? b.amount ?? 0);
    const seats = Number(b.numberOfSeats ?? 0);
    if (!seats || Number.isNaN(total)) return 0;
    return total / seats;
  });

  totalPrice = computed(() => {
    const b = this.booking();
    if (!b) return 0;
    const total = Number(b.totalPrice ?? b.amount ?? 0);
    if (!Number.isNaN(total) && total > 0) return total;
    return this.unitPrice() * Number(b.numberOfSeats ?? 0);
  });

  ngOnInit() {
    const bookingId = this.route.snapshot.paramMap.get('id');
    if (bookingId) {
      this.loadBookingDetails(+bookingId);
    }
  }

  loadBookingDetails(id: number) {
    this.bookingService.getBookingById(id).subscribe({
      next: (data) => this.booking.set(data),
      error: () => {
        this.notificationService.show('Impossible de charger cette réservation.', 'error');
        this.router.navigate(['/']);
      },
    });
  }

  confirmAndPay() {
    const bookingData = this.booking();
    if (!bookingData) {
      this.notificationService.show("Erreur d'identification de la réservation.", 'error');
      return;
    }
    const rawId = bookingData.id;
    const cleanId = Number(Array.isArray(rawId) ? rawId[0] : rawId);
    if (Number.isNaN(cleanId)) {
      this.notificationService.show("Erreur d'identification de la réservation.", 'error');
      return;
    }

    this.isProcessing.set(true);

    this.bookingService.getFedaPayUrl(cleanId).subscribe({
      next: (response) => {
        window.location.href = response.url;
      },
      error: () => {
        this.isProcessing.set(false);
        this.notificationService.show('Erreur technique. Veuillez réessayer.', 'error');
      },
    });
  }
}
