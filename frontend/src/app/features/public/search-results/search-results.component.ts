import { Component, DestroyRef, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import { Trip } from '../../../core/services/trip/trip.service';
import { getTripPublicListPrice } from '../../../core/utils/trip-public-list-price.util';
import { formatVehicleTypeLabel } from '../../../core/constants/vehicle-types';
import { isTripInProgress, tripInProgressLabel } from '../../../core/utils/trip-status-label.util';
import { SeoService } from '../../../core/services/seo/seo.service';
import { SearchResultsResolved } from './search-results.resolver';

@Component({
  selector: 'app-search-results',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './search-results.component.html',
  styleUrls: ['./search-results.component.scss'],
})
export class SearchResultsComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly destroyRef = inject(DestroyRef);
  private readonly seo = inject(SeoService);

  searchParams = { departure: '', arrival: '', date: '', transportType: '' };
  trips: Trip[] = [];
  error: string | null = null;

  listPrice = getTripPublicListPrice;
  formatVehicleType = formatVehicleTypeLabel;
  isTripInProgress = isTripInProgress;
  tripInProgressLabel = tripInProgressLabel;

  ngOnInit(): void {
    this.route.data.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((data) => {
      const result = data['result'] as SearchResultsResolved;
      this.searchParams = {
        departure: result.departure,
        arrival: result.arrival,
        date: result.date,
        transportType: result.transportType,
      };
      this.trips = result.trips;
      this.error = result.errored ? 'Impossible de charger les trajets. Réessayez plus tard.' : null;
      this.updateSeoForSearch(result.departure, result.arrival);
    });
  }

  /**
   * Titre dynamique par recherche (ex. "Trajets Abidjan → Dakar — Mobili") — cette route est en
   * RenderMode.Server (voir app.routes.server.ts), donc chaque requête est rendue à la demande
   * avec les vrais query params, contrairement aux pages Prerender dont le SEO est figé au build.
   */
  private updateSeoForSearch(departure: string, arrival: string): void {
    const hasBoth = departure && arrival;
    const title = hasBoth
      ? `Trajets ${departure} → ${arrival} — Mobili`
      : 'Résultats de recherche — Mobili';
    const description = hasBoth
      ? `Trouvez et réservez votre trajet bus, car ou covoiturage de ${departure} à ${arrival} avec Mobili.`
      : 'Trouvez et réservez votre trajet bus, car ou covoiturage en Afrique de l’Ouest avec Mobili.';
    this.seo.setPageSeo({ title, description, canonicalPath: '/search-results' });
  }
}
