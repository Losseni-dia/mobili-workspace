import { Component, DestroyRef, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

import { Trip } from '../../../core/services/trip/trip.service';
import { getTripPublicListPrice } from '../../../core/utils/trip-public-list-price.util';
import { formatVehicleTypeLabel } from '../../../core/constants/vehicle-types';
import { isTripInProgress, tripInProgressLabel } from '../../../core/utils/trip-status-label.util';
import { SeoService } from '../../../core/services/seo/seo.service';
import { TripLandingCity, findCityBySlug } from '../../../core/constants/trip-landing-cities';
import { CityPairTripsResult } from './city-pair-landing.resolver';
import { ConfigurationService } from '../../../configurations/services/configuration.service';
import { AuthService } from '../../../core/services/auth/auth.service';

const SITE_ORIGIN = 'https://www.my-mobili.com';

/**
 * Page indexable par liaison (ex. /trajets/abidjan/dakar) — backlog SEO section 2bis : contrairement
 * à /search-results (query params jamais remplis par Google), cette URL est fixe et linkée depuis
 * le sitemap, donc réellement crawlable. RenderMode.Server (voir app.routes.server.ts) : interroge
 * le backend en direct à chaque requête, jamais de données figées/fausses — si peu ou pas de
 * trajets existent sur cette liaison au moment du crawl, la page l'affiche honnêtement (état vide),
 * elle redevient pertinente automatiquement dès que de vrais trajets sont créés.
 *
 * Données chargées via un resolver de route (city-pair-landing.resolver.ts), pas un fetch dans
 * ngOnInit — c'est le resolver, pas `PendingTasks`, qui garantit que RenderMode.Server sérialise
 * le HTML avec les vraies données (voir commentaire du resolver pour l'historique du bug trouvé).
 *
 * Gabarit de carte trajet repris à l'identique de HomeComponent (catalogue accueil) — retour
 * utilisateur explicite préférant ce design (image véhicule, badges arrêts) à celui, plus sobre,
 * de SearchResultsComponent utilisé dans une première version de cette page.
 */
@Component({
  selector: 'app-city-pair-landing',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './city-pair-landing.component.html',
  styleUrl: '../home/home.component.scss',
})
export class CityPairLandingComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly destroyRef = inject(DestroyRef);
  private readonly seo = inject(SeoService);
  private readonly configuration = inject(ConfigurationService);
  private readonly authService = inject(AuthService);

  fromCity: TripLandingCity | null = null;
  toCity: TripLandingCity | null = null;
  /** Aucune des deux villes de l'URL n'est reconnue dans la config — état "liaison non disponible". */
  invalidRoute = false;

  trips: Trip[] = [];
  error: string | null = null;

  listPrice = getTripPublicListPrice;
  formatVehicleType = formatVehicleTypeLabel;
  isTripInProgress = isTripInProgress;
  tripInProgressLabel = tripInProgressLabel;

  /** URL finale photo véhicule — alignée sur l'origine de l'API (pas `localhost` en dur). */
  tripVehicleImageSrc(tripVehiclePath: string | null | undefined): string {
    return this.configuration.resolveUploadMediaUrl(tripVehiclePath ?? null) ?? '';
  }

  buildVehicleAltText(trip: Trip): string {
    const vehicle = this.formatVehicleType(trip.vehicleType);
    return `Véhicule ${vehicle} — trajet ${trip.departureCity} → ${trip.arrivalCity}`;
  }

  openBooking(trip: Trip): void {
    if (!this.authService.currentUser()) {
      this.router.navigate(['/auth/login']);
      return;
    }
    this.router.navigate(['/booking/trip', trip.id]);
  }

  ngOnInit(): void {
    this.route.data.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((data) => {
      const result = data['result'] as CityPairTripsResult;
      const fromSlug = this.route.snapshot.paramMap.get('from') ?? '';
      const toSlug = this.route.snapshot.paramMap.get('to') ?? '';
      const from = findCityBySlug(fromSlug);
      const to = findCityBySlug(toSlug);

      this.fromCity = from ?? null;
      this.toCity = to ?? null;
      this.invalidRoute = !from || !to;
      this.trips = result.trips;
      this.error = result.errored ? 'Impossible de charger les trajets. Réessayez plus tard.' : null;

      if (from && to) {
        this.updateSeo(from, to);
      }
    });
  }

  private updateSeo(from: TripLandingCity, to: TripLandingCity): void {
    const title = `Trajets ${from.name} → ${to.name} — Mobili`;
    const description = `Trouvez et réservez votre trajet bus, car ou covoiturage de ${from.name} à ${to.name} avec Mobili. Paiement Wave, Orange Money, MTN Money, carte bancaire.`;
    const canonicalPath = `/trajets/${this.route.snapshot.paramMap.get('from')}/${this.route.snapshot.paramMap.get('to')}`;
    this.seo.setPageSeo({ title, description, canonicalPath });
    this.seo.setStructuredData({
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: 'Accueil', item: SITE_ORIGIN },
        { '@type': 'ListItem', position: 2, name: from.name, item: `${SITE_ORIGIN}${canonicalPath}` },
        { '@type': 'ListItem', position: 3, name: to.name, item: `${SITE_ORIGIN}${canonicalPath}` },
      ],
    });
  }
}
