import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError } from 'rxjs/operators';

export interface SeatSelection {
  passengerName: string;
  seatNumber: string;
}

export interface BookingRequest {
  tripId: number;
  userId: number;
  numberOfSeats: number;
  selections: SeatSelection[];
  /** Index de l'arrêt d'embarquement (0 = ville de départ). */
  boardingStopIndex?: number;
  /** Index de l'arrêt de descente (dernier = ville d'arrivée). */
  alightingStopIndex?: number;
  /** Bagages soute en plus (hors quota inclus). */
  extraHoldBags?: number;
}

export interface BookingResponse {
  id: number;
  reference: string;
  customerName?: string;
  tripRoute?: string;
  departureCity: string;
  arrivalCity: string;
  moreInfo?: string;
  departureDateTime: string;
  date?: string;
  numberOfSeats: number;
  seatNumbers: string[];
  passengerNames?: string[];
  totalPrice: number;
  /** Alias conservé pour les anciennes vues partenaire. */
  amount?: number;
  pricePerSeat?: number;
  boardingStopIndex?: number;
  alightingStopIndex?: number;
  boardingCity?: string;
  alightingCity?: string;
  status: string;
  bookingDate?: string;
  extraHoldBags?: number;
  luggageFee?: number;
}

export interface PaymentCheckoutResponse {
  url: string;
}

/** Réponse de POST /payments/verify/{bookingId} */
export interface PaymentVerifyResponse {
  confirmed: boolean;
  status: string;
}

@Injectable({ providedIn: 'root' })
export class BookingService {
  private http = inject(HttpClient);
  private readonly API_URL = '/bookings';

  /**
   * ✅ Récupère les sièges occupés.
   * Si l'API échoue, on renvoie [] pour que le bus s'affiche quand même.
   */
  getOccupiedSeats(
    tripId: number,
    boardingStopIndex?: number,
    alightingStopIndex?: number,
  ): Observable<string[]> {
    let params = new HttpParams();
    if (boardingStopIndex != null) {
      params = params.set('boardingStopIndex', String(boardingStopIndex));
    }
    if (alightingStopIndex != null) {
      params = params.set('alightingStopIndex', String(alightingStopIndex));
    }
    return this.http
      .get<string[]>(`${this.API_URL}/trips/${tripId}/occupied-seats`, { params })
      .pipe(catchError(() => of([])));
  }

  /**
   * Enregistre la réservation et les sièges choisis
   */
  createBooking(bookingData: BookingRequest): Observable<BookingResponse> {
    return this.http.post<BookingResponse>(this.API_URL, bookingData);
  }

  confirmPayment(bookingId: number): Observable<void> {
    return this.http.patch<void>(`${this.API_URL}/${bookingId}/confirm`, {});
  }

  getUserBookings(userId: number): Observable<BookingResponse[]> {
    return this.http.get<BookingResponse[]>(`${this.API_URL}/user/${userId}`);
  }

  getBookingById(id: number): Observable<BookingResponse> {
    return this.http.get<BookingResponse>(`${this.API_URL}/${id}`);
  }

  getFedaPayUrl(bookingId: number): Observable<PaymentCheckoutResponse> {
    // On met juste /payments car l'intercepteur va ajouter le reste
    return this.http.post<PaymentCheckoutResponse>(`/payments/checkout/${bookingId}`, {});
  }

  /**
   * Après retour FedaPay : relit le statut sur l'API FedaPay et confirme la réservation (billets)
   * si le webhook n'a pas pu joindre le backend (ex. localhost).
   */
  verifyFedaPayPayment(bookingId: number): Observable<PaymentVerifyResponse> {
    return this.http.post<PaymentVerifyResponse>(`/payments/verify/${bookingId}`, {});
  }

  getPartnerBookings(): Observable<BookingResponse[]> {
    return this.http.get<BookingResponse[]>('/bookings/partner/my-bookings');
  }

  /**
   * ✅ Désactive manuellement des places (Vente à la gare)
   */
  deactivateSeats(tripId: number, seatNumbers: string[]): Observable<void> {
    return this.http.post<void>(`${this.API_URL}/partner/deactivate-seats`, {
      tripId,
      seatNumbers,
    });
  }
}
