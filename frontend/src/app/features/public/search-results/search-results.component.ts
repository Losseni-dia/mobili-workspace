import { Component, DestroyRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { switchMap, tap } from 'rxjs/operators';

import { TripService, Trip } from '../../../core/services/trip/trip.service';
import { getTripPublicListPrice } from '../../../core/utils/trip-public-list-price.util';
import { formatVehicleTypeLabel } from '../../../core/constants/vehicle-types';

@Component({
  selector: 'app-search-results',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './search-results.component.html',
  styleUrls: ['./search-results.component.scss'],
})
export class SearchResultsComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly tripService = inject(TripService);
  private readonly destroyRef = inject(DestroyRef);

  searchParams = { departure: '', arrival: '', date: '', transportType: '' };
  trips: Trip[] = [];
  loading = false;
  error: string | null = null;

  listPrice = getTripPublicListPrice;

  constructor() {
    this.route.queryParams
      .pipe(
        tap(() => {
          this.loading = true;
          this.error = null;
        }),
        switchMap((params) => {
          const departure = String(params['departure'] ?? params['from'] ?? '').trim();
          const arrival = String(params['arrival'] ?? params['to'] ?? '').trim();
          const date = String(params['date'] ?? '').trim();
          const transportType = String(params['transportType'] ?? '').trim();
          this.searchParams = { departure, arrival, date, transportType };
          return this.tripService.searchTrips(
            departure,
            arrival,
            date,
            transportType || undefined,
          );
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe({
        next: (data) => {
          this.trips = data;
          this.loading = false;
        },
        error: () => {
          this.trips = [];
          this.loading = false;
          this.error = 'Impossible de charger les trajets. Réessayez plus tard.';
        },
      });
  }

  formatVehicleType = formatVehicleTypeLabel;
}
