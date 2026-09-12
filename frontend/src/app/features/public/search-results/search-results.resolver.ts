import { inject } from '@angular/core';
import { ResolveFn } from '@angular/router';
import { catchError, map, of } from 'rxjs';

import { TripService, Trip } from '../../../core/services/trip/trip.service';

export interface SearchResultsResolved {
  trips: Trip[];
  errored: boolean;
  departure: string;
  arrival: string;
  date: string;
  transportType: string;
}

/**
 * Résolveur de route — un fetch fait dans le constructeur/ngOnInit (approche initiale, voir
 * historique du commit) ne bloque pas RenderMode.Server : confirmé par instrumentation directe
 * sur la page /trajets/:from/:to (même pattern) que le HTML SSR se sérialise avant la fin de la
 * requête HTTP, peu importe `PendingTasks`. Un resolver, lui, bloque réellement la navigation du
 * Router — mécanisme central, pas une astuce SSR.
 *
 * Cette route lit des QUERY params (departure/arrival/date/transportType), pas des path params —
 * `runGuardsAndResolvers: 'paramsOrQueryParamsChange'` est nécessaire côté route (voir
 * app.routes.ts) pour que ce resolver se relance à chaque nouvelle recherche côté client, pas
 * seulement au premier chargement (comportement par défaut du Router : les resolvers ne se
 * relancent pas sur un simple changement de query params).
 */
export const searchResultsResolver: ResolveFn<SearchResultsResolved> = (route) => {
  const tripService = inject(TripService);
  const departure = String(route.queryParamMap.get('departure') ?? route.queryParamMap.get('from') ?? '').trim();
  const arrival = String(route.queryParamMap.get('arrival') ?? route.queryParamMap.get('to') ?? '').trim();
  const date = String(route.queryParamMap.get('date') ?? '').trim();
  const transportType = String(route.queryParamMap.get('transportType') ?? '').trim();

  return tripService.searchTrips(departure, arrival, date, transportType || undefined).pipe(
    map((trips) => ({ trips, errored: false, departure, arrival, date, transportType })),
    catchError(() => of({ trips: [], errored: true, departure, arrival, date, transportType })),
  );
};
