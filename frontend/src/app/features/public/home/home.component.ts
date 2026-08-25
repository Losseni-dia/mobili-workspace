import { Component, OnInit, inject, signal, ChangeDetectorRef } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { debounceTime, distinctUntilChanged, switchMap } from 'rxjs/operators';
import { DestroyRef } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import { ConfigurationService } from '../../../configurations/services/configuration.service';
import { TripService, Trip } from '../../../core/services/trip/trip.service';
import { getTripPublicListPrice } from '../../../core/utils/trip-public-list-price.util';
import { AuthService } from '../../../core/services/auth/auth.service';
import { formatVehicleTypeLabel } from '../../../core/constants/vehicle-types';
import { isTripInProgress, tripInProgressLabel } from '../../../core/utils/trip-status-label.util';

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
  private configuration = inject(ConfigurationService);

  filteredTrips: Trip[] = [];
  loadingTrips = false;

  /** URL finale photo véhicule — alignée sur l’origine de l’API (pas `localhost` en dur). */
  tripVehicleImageSrc(tripVehiclePath: string | null | undefined): string {
    return this.configuration.resolveUploadMediaUrl(tripVehiclePath ?? null) ?? '';
  }

  /** Prix catalogue départ → arrivée (saisi à la création, pas somme des tronçons). */
  listPrice = getTripPublicListPrice;

  searchForm = this.fb.group({
    departure: [''],
    arrival: [''],
    date: [''],
    /** Vide = tous ; PUBLIC = transport public / lignes ; COVOITURAGE */
    transportType: [''],
  });

  /**
   * Autocomplétion ville — alignée sur `CityAutocompleteField` (mobile_app), même
   * endpoint `GET /trips/cities`. Un champ actif à la fois (celui avec le focus).
   */
  departureSuggestions = signal<string[]>([]);
  arrivalSuggestions = signal<string[]>([]);
  activeField = signal<'departure' | 'arrival' | null>(null);

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

    this.searchForm
      .get('departure')!
      .valueChanges.pipe(
        debounceTime(200),
        distinctUntilChanged(),
        switchMap((q) => this.tripService.getCities(q ?? '')),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((cities) => {
        this.departureSuggestions.set(cities);
        this.cdr.markForCheck();
      });

    this.searchForm
      .get('arrival')!
      .valueChanges.pipe(
        debounceTime(200),
        distinctUntilChanged(),
        switchMap((q) => this.tripService.getCities(q ?? '')),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((cities) => {
        this.arrivalSuggestions.set(cities);
        this.cdr.markForCheck();
      });
  }

  onCityFieldFocus(field: 'departure' | 'arrival'): void {
    this.activeField.set(field);
  }

  /** Délai court pour laisser le temps au (click) sur une suggestion de se déclencher. */
  onCityFieldBlur(): void {
    setTimeout(() => this.activeField.set(null), 150);
  }

  selectCity(field: 'departure' | 'arrival', city: string): void {
    this.searchForm.get(field)?.setValue(city);
    this.activeField.set(null);
  }

  /** Petite croix "vider le champ" — évite de tout effacer au clavier. */
  clearField(field: 'departure' | 'arrival'): void {
    this.searchForm.get(field)?.setValue('');
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
  isTripInProgress = isTripInProgress;
  tripInProgressLabel = tripInProgressLabel;

  resetFilter(): void {
    this.searchForm.reset({ departure: '', arrival: '', date: '', transportType: '' });
    this.loadAllTrips();
  }

}
