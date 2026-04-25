import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface TripLegFarePayload {
  fromStopIndex: number;
  toStopIndex: number;
  price: number;
}

/** Brouillon pour POST /trips/price-preview (partenaire / admin). */
export interface TripPricePreviewDraft {
  departureCity: string;
  arrivalCity: string;
  moreInfo: string;
  price: number;
  /** ISO local type `yyyy-MM-ddTHH:mm:ss` (sans offset), optionnel. */
  departureDateTime?: string | null;
  /** Tronçons consécutifs : si présent, même logique qu’à la sauvegarde du voyage. */
  legFares?: TripLegFarePayload[];
  /**
   * Prix 1er → dernier arrêt (si 2+ tronçons) : peut différer de la somme des tronçons.
   * Utilisé pour l’aperçu embarquement=0, descente=dernier.
   */
  originDestinationPrice?: number | null;
}

export interface TripPricePreviewStop {
  stopIndex: number;
  cityLabel: string;
  plannedDepartureAt: string;
}

export interface TripPricePreviewResponse {
  pricePerSeat: number;
  lastStopIndex: number;
  stops: TripPricePreviewStop[];
}

export interface TripLegFareResponse {
  fromStopIndex: number;
  toStopIndex: number;
  price: number;
}

export interface Trip {
  id: number;
  departureCity: string;
  arrivalCity: string;
  boardingPoint: string;
  departureDateTime: string;
  price: number;
  /** Tarif direct premier → dernier arrêt (si renseigné, peut différer de la somme des tronçons). */
  originDestinationPrice?: number | null;
  totalSeats: number;
  availableSeats: number;
  vehicleType: string;
  vehicleImageUrl?: string;
  moreInfo?: string;
  status?: string;
  partnerName?: string;
  stationId?: number;
  stationName?: string;
  /** Tarifs enregistrés par le partenaire pour chaque portion consécutive. */
  legFares?: TripLegFareResponse[];
  /** PUBLIC = transport en ligne / public ; COVOITURAGE */
  transportType?: string;
  /** Présent si offre covoiturage particulier (hors compagnie). */
  covoiturageOrganizerId?: number | null;
  /** Chauffeur salarié affecté au service (dispatch gare ou partenaire). */
  assignedChauffeurId?: number | null;
  assignedChauffeurFirstname?: string | null;
  assignedChauffeurLastname?: string | null;

  /** Politique bagages (défaut côté API : 1 cabine + 1 soute inclus, 1 soute max en plus payant). */
  includedCabinBagsPerPassenger?: number;
  includedHoldBagsPerPassenger?: number;
  maxExtraHoldBagsPerPassenger?: number;
  extraHoldBagPrice?: number;
}

@Injectable({ providedIn: 'root' })
export class TripService {
  private http = inject(HttpClient);

  createTrip(formData: FormData): Observable<Trip> {
    // On envoie le formData directement sans préciser de headers
    return this.http.post<Trip>('/trips', formData);
  }
  // Pour charger tous les voyages par défaut sur la Home
  getAllTrips(transportType?: string): Observable<Trip[]> {
    let params = new HttpParams();
    if (transportType && transportType.trim() !== '') {
      params = params.set('transportType', transportType.trim().toUpperCase());
    }
    return this.http.get<Trip[]>('/trips', { params });
  }

  /**
   * Recherche segmentée côté API (`GET /trips/search`).
   * Paramètres alignés sur le backend : `departure`, `arrival`, `date` (optionnelle, ISO yyyy-MM-dd).
   */
  searchTrips(departure: string, arrival: string, date: string, transportType?: string): Observable<Trip[]> {
    let params = new HttpParams()
      .set('departure', departure ?? '')
      .set('arrival', arrival ?? '');
    if (date && String(date).trim() !== '') {
      params = params.set('date', String(date).trim());
    }
    if (transportType && transportType.trim() !== '') {
      params = params.set('transportType', transportType.trim().toUpperCase());
    }
    return this.http.get<Trip[]>('/trips/search', { params });
  }

  getTripById(id: number): Observable<any> {
    return this.http.get<any>(`/trips/${id}`); // Vérifie que l'URL correspond à ton JSON
  }

  updateTrip(id: number, formData: FormData): Observable<Trip> {
    // On utilise PUT avec le FormData
    return this.http.put<Trip>(`/trips/${id}`, formData);
  }

  deleteTrip(id: number): Observable<void> {
    // Utilisation directe de la chaîne pour être raccord avec tes autres méthodes
    return this.http.delete<void>(`/trips/${id}`);
  }

  getPartnerTrips(): Observable<Trip[]> {
    return this.http.get<Trip[]>('/trips/my-trips');
  }

  getCovoiturageSoloMyTrips(): Observable<Trip[]> {
    return this.http.get<Trip[]>('/covoiturage/trips/mine');
  }

  createCovoiturageSoloTrip(formData: FormData): Observable<Trip> {
    return this.http.post<Trip>('/covoiturage/trips', formData);
  }

  deleteCovoiturageSoloTrip(id: number): Observable<void> {
    return this.http.delete<void>(`/covoiturage/trips/${id}`);
  }

  /**
   * Aperçu tarif segment : même calcul que la réservation (JWT partenaire ou admin).
   */
  previewSegmentPrice(body: {
    departureCity: string;
    arrivalCity: string;
    moreInfo: string;
    price: number;
    boardingStopIndex: number;
    alightingStopIndex: number;
    departureDateTime?: string | null;
    legFares?: TripLegFarePayload[];
    originDestinationPrice?: number | null;
  }): Observable<TripPricePreviewResponse> {
    const payload: Record<string, unknown> = {
      departureCity: body.departureCity,
      arrivalCity: body.arrivalCity,
      moreInfo: body.moreInfo ?? '',
      price: body.price,
      boardingStopIndex: body.boardingStopIndex,
      alightingStopIndex: body.alightingStopIndex,
    };
    if (body.departureDateTime != null && String(body.departureDateTime).trim() !== '') {
      payload['departureDateTime'] = body.departureDateTime;
    }
    if (body.legFares != null && body.legFares.length > 0) {
      payload['legFares'] = body.legFares;
    }
    if (body.originDestinationPrice != null && !Number.isNaN(Number(body.originDestinationPrice))) {
      payload['originDestinationPrice'] = Number(body.originDestinationPrice);
    }
    return this.http.post<TripPricePreviewResponse>('/trips/price-preview', payload);
  }
}
