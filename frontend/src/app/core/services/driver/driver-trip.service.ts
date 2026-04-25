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

export interface DriverLuggageSummary {
  includedCabinBagsPerPassenger: number;
  includedHoldBagsPerPassenger: number;
  maxExtraHoldBagsPerPassenger: number;
  extraHoldBagPrice: number;
  confirmedPassengerSeats: number;
  expectedIncludedHoldBags: number;
  expectedIncludedCabinBags: number;
  totalExtraHoldBagsReserved: number;
  maxPossibleExtraHoldBags: number;
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

  getLuggageSummary(tripId: number): Observable<DriverLuggageSummary> {
    return this.http.get<DriverLuggageSummary>(`/trips/${tripId}/driver/luggage-summary`);
  }

  listAlightings(tripId: number, stopIndex: number): Observable<AlightingPassengerRow[]> {
    return this.http.get<AlightingPassengerRow[]>(
      `/trips/${tripId}/driver/stops/${stopIndex}/alightings`,
    );
  }

  recordDeparture(tripId: number, stopIndex: number): Observable<void> {
    return this.http.post<void>(`/trips/${tripId}/driver/departures`, { stopIndex });
  }

  confirmAlighted(
    tripId: number,
    ticketNumber: string,
    stopIndex?: number | null,
  ): Observable<unknown> {
    const path = `/trips/${tripId}/driver/tickets/${encodeURIComponent(ticketNumber)}/alighted`;
    const hasStop = stopIndex != null && !Number.isNaN(Number(stopIndex));
    const body = hasStop ? { stopIndex: Number(stopIndex) } : {};
    return this.http.post(path, body);
  }
}
