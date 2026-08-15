import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';

export interface ChauffeurTripListItem {
  id: number;
  source: 'ASSIGNED' | 'COVOITURAGE' | string;
  departureCity: string;
  arrivalCity: string;
  boardingPoint?: string | null;
  departureDateTime: string;
  status: string;
  partnerName?: string | null;
  stationName?: string | null;
  vehiculePlateNumber?: string | null;
  vehicleType?: string | null;
}

export interface ChauffeurTripsOverview {
  upcoming: ChauffeurTripListItem[];
  history: ChauffeurTripListItem[];
}

export interface TripStopRow {
  stopIndex: number;
  cityLabel: string;
  plannedDepartureAt: string;
}

export interface AlightingPassengerRow {
  ticketNumber: string;
  passengerName: string;
  seatNumber: string;
  ticketStatus: string;
  boardingStopIndex: number;
}

@Injectable({ providedIn: 'root' })
export class DriverTripService {
  private readonly http = inject(HttpClient);

  /** Ligne : trajets affectes + covoit : mes offres. */
  getChauffeurTripsOverview(): Observable<ChauffeurTripsOverview> {
    return this.http.get<ChauffeurTripsOverview>('/trips/chauffeur/mine');
  }

  /** Passe le voyage en EN_COURS et enregistre le depart au premier arret. */
  startTrip(tripId: number): Observable<void> {
    return this.http.post<void>(`/trips/${tripId}/driver/start`, {});
  }

  listStops(tripId: number): Observable<TripStopRow[]> {
    return this.http.get<TripStopRow[]>(`/trips/${tripId}/stops`);
  }

  listAlightings(tripId: number, stopIndex: number): Observable<AlightingPassengerRow[]> {
    return this.http.get<AlightingPassengerRow[]>(
      `/trips/${tripId}/driver/stops/${stopIndex}/alightings`,
    );
  }

  /** Passagers qui montent à cet arrêt — même DTO que les descentes, purement informatif. */
  listBoardings(tripId: number, stopIndex: number): Observable<AlightingPassengerRow[]> {
    return this.http.get<AlightingPassengerRow[]>(
      `/trips/${tripId}/driver/stops/${stopIndex}/boardings`,
    );
  }

  recordDeparture(tripId: number, stopIndex: number): Observable<void> {
    return this.http.post<void>(`/trips/${tripId}/driver/departures`, { stopIndex });
  }

  /**
   * Annule le dernier départ enregistré (le plus récent arrêt marqué "parti") : repasse les
   * tickets auto-marqués ARRIVÉ à cet arrêt en UTILISÉ, et le trajet en PROGRAMMÉ/EN_COURS selon
   * l'arrêt courant résultant. 400 si aucun départ à annuler.
   */
  undoLastDeparture(tripId: number): Observable<{ currentStopIndex: number }> {
    return this.http.post<{ currentStopIndex: number }>(`/trips/${tripId}/driver/departures/undo`, {});
  }
}
