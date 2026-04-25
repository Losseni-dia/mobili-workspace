import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { DestroyRef } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import { TripService, Trip } from '../../../core/services/trip/trip.service';
import { getTripPublicListPrice } from '../../../core/utils/trip-public-list-price.util';
import { AuthService } from '../../../core/services/auth/auth.service';
import { formatVehicleTypeLabel } from '../../../core/constants/vehicle-types';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [ReactiveFormsModule, CommonModule, FormsModule, RouterModule],
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.scss'],
})
export class HomeComponent implements OnInit {
  private fb = inject(FormBuilder);
  private cdr = inject(ChangeDetectorRef);
  private tripService = inject(TripService);
  private authService = inject(AuthService);
  private router = inject(Router);
  private destroyRef = inject(DestroyRef);

  filteredTrips: Trip[] = [];
  loadingTrips = false;

  readonly IMAGE_BASE_URL = 'http://localhost:8080/uploads/';

  /** Prix catalogue départ → arrivée (saisi à la création, pas somme des tronçons). */
  listPrice = getTripPublicListPrice;

  searchForm = this.fb.group({
    departure: [''],
    arrival: [''],
    date: [''],
    /** Vide = tous ; PUBLIC = transport public / lignes ; COVOITURAGE */
    transportType: [''],
  });

  constructor() {
    this.searchForm.valueChanges
      .pipe(
        debounceTime(300),
        distinctUntilChanged(
          (a, b) =>
            a.departure === b.departure &&
            a.arrival === b.arrival &&
            a.date === b.date &&
            a.transportType === b.transportType,
        ),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe(() => this.refreshTripsFromForm());
  }

  ngOnInit(): void {
    this.loadAllTrips();
  }

  private loadAllTrips(): void {
    this.loadingTrips = true;
    const tt = this.searchForm.get('transportType')?.value?.trim() ?? '';
    this.tripService.getAllTrips(tt || undefined).subscribe({
      next: (data) => {
        this.filteredTrips = data;
        this.loadingTrips = false;
        this.cdr.markForCheck();
      },
      error: (err) => {
        console.error('[home] Chargement des voyages (GET /trips) :', err);
        this.loadingTrips = false;
        this.filteredTrips = [];
        this.cdr.markForCheck();
      },
    });
  }

  /**
   * Source de vérité : API `/trips/search` dès qu’au moins départ ou arrivée est saisi.
   * Catalogue complet via `GET /trips` si les deux champs ville sont vides.
   */
  private refreshTripsFromForm(): void {
    const { departure, arrival, date, transportType } = this.searchForm.getRawValue();
    const d = departure?.trim() ?? '';
    const a = arrival?.trim() ?? '';
    const dt = date ?? '';
    const tt = transportType?.trim() ?? '';

    if (!d && !a) {
      this.loadAllTrips();
      return;
    }

    this.loadingTrips = true;
    this.tripService.searchTrips(d, a, dt, tt || undefined).subscribe({
      next: (data) => {
        this.filteredTrips = data;
        this.loadingTrips = false;
        this.cdr.markForCheck();
      },
      error: (err) => {
        console.error('[home] Recherche voyages (GET /trips/search) :', err);
        this.filteredTrips = [];
        this.loadingTrips = false;
        this.cdr.markForCheck();
      },
    });
  }

  openBooking(trip: Trip): void {
    if (!this.authService.currentUser()) {
      this.router.navigate(['/auth/login']);
      return;
    }
    this.router.navigate(['/booking/trip', trip.id]);
  }

  formatVehicleType = formatVehicleTypeLabel;

  resetFilter(): void {
    this.searchForm.reset({ departure: '', arrival: '', date: '', transportType: '' });
    this.loadAllTrips();
  }

  transportTypeLabel(trip: Trip): string {
    if (trip.transportType === 'COVOITURAGE') return 'Covoiturage';
    return 'Transport public';
  }
}
