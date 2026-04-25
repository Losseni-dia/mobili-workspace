import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { TripService, Trip } from '../../../core/services/trip/trip.service';
import { getTripPublicListPrice } from '../../../core/utils/trip-public-list-price.util';
import { SeatPickerComponent } from '../../booking/components/seat-picker/seat-picker.component';
import { BookingService } from '../../../core/services/booking/booking.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { formatVehicleTypeLabel } from '../../../core/constants/vehicle-types';

@Component({
  selector: 'app-trip-management',
  standalone: true,
  imports: [CommonModule, RouterModule, SeatPickerComponent],
  templateUrl: './trip-management.component.html',
  styleUrls: ['./trip-management.component.scss'],
})
export class TripManagementComponent implements OnInit {
  private tripService = inject(TripService);
  private bookingService = inject(BookingService);
  private notify = inject(NotificationService);

  myTrips = signal<Trip[]>([]);
  isLoading = signal(false);

  /** ID du trajet dont on vient de copier le code chauffeur (pour feedback UI). */
  copiedTripId = signal<number | null>(null);

  // Gestion du blocage des places
  selectedTripForSeats = signal<Trip | null>(null);
  occupiedSeatsForTrip = signal<string[]>([]);
  tempSelectedSeats = signal<string[]>([]);

  readonly IMAGE_BASE_URL = 'http://localhost:8080/uploads/';

  listPrice = getTripPublicListPrice;

  chauffeurLabel(t: Trip): string {
    if (t.assignedChauffeurId == null || t.assignedChauffeurId <= 0) {
      return '—';
    }
    const fn = t.assignedChauffeurFirstname?.trim() ?? '';
    const ln = t.assignedChauffeurLastname?.trim() ?? '';
    const s = `${fn} ${ln}`.trim();
    return s || `#${t.assignedChauffeurId}`;
  }

  ngOnInit(): void {
    this.loadTrips();
  }

  loadTrips(): void {
    this.isLoading.set(true);
    this.tripService.getPartnerTrips().subscribe({
      next: (data: Trip[]) => {
        this.myTrips.set(Array.isArray(data) ? data : []);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement mes trajets :', err);
        this.myTrips.set([]);
        this.isLoading.set(false);
      },
    });
  }

  openSeatManager(trip: Trip) {
    this.selectedTripForSeats.set(trip);
    this.tempSelectedSeats.set([]);

    this.bookingService.getOccupiedSeats(trip.id).subscribe({
      next: (occupiedSeats: string[]) => {
        this.occupiedSeatsForTrip.set(occupiedSeats);
      },
      error: (err) => {
        console.error('Erreur chargement places occupées', err);
        this.occupiedSeatsForTrip.set([]);
      },
    });
  }

  onSeatsSelected(seats: string[]) {
    this.tempSelectedSeats.set(seats);
  }

  confirmDeactivation() {
    const tripId = this.selectedTripForSeats()?.id;
    if (!tripId || this.tempSelectedSeats().length === 0) return;

    this.bookingService.deactivateSeats(tripId, this.tempSelectedSeats()).subscribe({
      next: () => {
        this.selectedTripForSeats.set(null);
        this.loadTrips(); // Rafraîchit le tableau pour voir la baisse de places disponibles
      },
      error: (err) => console.error('Erreur lors de la désactivation', err),
    });
  }

  formatVehicleType = formatVehicleTypeLabel;

  /**
   * Copie l'identifiant du voyage dans le presse-papier
   * (à transmettre au chauffeur pour démarrer sa console).
   */
  copyTripId(tripId: number, ev?: Event) {
    ev?.stopPropagation();
    const value = String(tripId);
    const onSuccess = () => {
      this.copiedTripId.set(tripId);
      this.notify.show(`ID voyage #${tripId} copié — à transmettre au chauffeur.`, 'success');
      setTimeout(() => {
        if (this.copiedTripId() === tripId) this.copiedTripId.set(null);
      }, 2200);
    };

    if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(value).then(onSuccess, () => this.fallbackCopy(value, onSuccess));
    } else {
      this.fallbackCopy(value, onSuccess);
    }
  }

  private fallbackCopy(value: string, onSuccess: () => void) {
    try {
      const ta = document.createElement('textarea');
      ta.value = value;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      onSuccess();
    } catch {
      this.notify.show('Impossible de copier automatiquement, sélectionne le numéro à la main.', 'error');
    }
  }

  onDelete(id: number) {
    if (confirm('Êtes-vous sûr de vouloir supprimer ce trajet ?')) {
      this.tripService.deleteTrip(id).subscribe({
        next: () => {
          this.myTrips.update((trips) => trips.filter((t) => t.id !== id));
        },
        error: (err) => console.error('Erreur suppression :', err),
      });
    }
  }
}
