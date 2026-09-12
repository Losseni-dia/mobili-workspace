import { inject } from '@angular/core';
import { ResolveFn } from '@angular/router';
import { catchError, map, of } from 'rxjs';

import { TripService, Trip } from '../../../core/services/trip/trip.service';
import { findCityBySlug } from '../../../core/constants/trip-landing-cities';

export interface CityPairTripsResult {
  trips: Trip[];
  errored: boolean;
}

/**
 * Résolveur de route — contrairement à un fetch fait dans `ngOnInit` (essayé en premier, voir
 * historique du commit), un resolver bloque réellement la navigation du Router tant que ses
 * données ne sont pas prêtes. C'est ce mécanisme, pas `PendingTasks`, qui garantit que le HTML
 * généré par RenderMode.Server contient les vrais trajets (ou l'état vide) au lieu d'un instantané
 * "Chargement…" figé — confirmé par instrumentation directe : `PendingTasks.add()` dans `ngOnInit`
 * n'empêchait pas `RenderMode.Server` de sérialiser le HTML avant la fin de la requête HTTP,
 * peu importe l'ordre d'appel.
 */
export const cityPairTripsResolver: ResolveFn<CityPairTripsResult> = (route) => {
  const tripService = inject(TripService);
  const from = findCityBySlug(route.paramMap.get('from') ?? '');
  const to = findCityBySlug(route.paramMap.get('to') ?? '');

  if (!from || !to) {
    return of({ trips: [], errored: false });
  }

  // Pas de date : tous les trajets à venir sur cette liaison, pas ceux d'un seul jour (le backend
  // ignore le filtre date quand il est vide, voir TripService côté back).
  return tripService.searchTrips(from.name, to.name, '', undefined).pipe(
    map((trips) => ({ trips, errored: false })),
    // Un resolver qui erreure bloque la navigation entière (page d'erreur Router) — on préfère
    // afficher la page avec un message d'erreur géré par le composant, jamais planter la nav.
    catchError(() => of({ trips: [], errored: true })),
  );
};
