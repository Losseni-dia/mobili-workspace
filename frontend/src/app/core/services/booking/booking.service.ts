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
  numberOfSeats: number;
  selections: SeatSelection[];
  /** Index de l'arrêt d'embarquement (0 = ville de départ). */
  boardingStopIndex?: number;
  /** Index de l'arrêt de descente (dernier = ville d'arrivée). */
  alightingStopIndex?: number;
  /** Bagages soute en plus (hors quota inclus). */
  extraHoldBags?: number;
  /** Code promo — même calcul serveur que /bookings/price-preview. */
  couponCode?: string | null;
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
  /** Montant total de la réservation (tickets + forfait client + bagages). */
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
  /**
   * Somme des prix de tickets seule (hors forfait client, hors bagages) — à afficher dans
   * « Mes réservations », jamais `totalPrice`. Absent sur les réservations créées avant le
   * forfait client : retomber sur `totalPrice` dans ce cas (pas de recalcul rétroactif).
   */
  ticketsTotalAmount?: number;
  /** Forfait client appliqué (100/200/300 FCFA) — absent sur les réservations antérieures. */
  serviceFee?: number;
  /** Covoiturage uniquement : délai de réponse du conducteur à la demande. */
  driverResponseDeadline?: string | null;
  /** Covoiturage uniquement : une fois la demande acceptée, fenêtre de paiement (~30 min). */
  paymentDeadline?: string | null;
}

export interface BookingPricePreviewRequest {
  tripId: number;
  numberOfSeats: number;
  boardingStopIndex?: number;
  alightingStopIndex?: number;
  extraHoldBags?: number;
  couponCode?: string | null;
}

/** Détail affichable au passager avant paiement — même calcul que la création réelle. */
export interface BookingPricePreviewResponse {
  seatSubtotal: number;
  serviceFee: number;
  luggageFee: number;
  total: number;
}

export interface PaymentCheckoutResponse {
  url: string;
}

/** Aligné sur PartnerTransactionResponse (backend) — détail financier par réservation payée. */
export interface PartnerTransaction {
  bookingId: number;
  reference: string;
  date: string;
  route: string;
  /** Vente brute compagnie, jamais le forfait client. */
  grossAmount: number;
  /** Commission Mobili prélevée sur cette réservation. */
  commissionTotal: number;
  /** grossAmount - commissionTotal, net réellement dû à la compagnie. */
  companyNet: number;
  status: string;
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

  /**
   * Prévisualise le prix (sous-total, forfait client, bagages, total) sans créer de
   * réservation — même calcul serveur que `createBooking`, pour afficher le détail avant
   * paiement plutôt qu'un total local qui omettrait le forfait client.
   */
  previewPrice(req: BookingPricePreviewRequest): Observable<BookingPricePreviewResponse> {
    return this.http.post<BookingPricePreviewResponse>(`${this.API_URL}/price-preview`, req);
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

  getFedaPayUrl(bookingId: number, customerEmail?: string | null): Observable<PaymentCheckoutResponse> {
    // On met juste /payments car l'intercepteur va ajouter le reste
    // ⚠️ Le backend (PaymentRequest) exige `provider` : un corps vide fait passer
    // `request.provider()` à null côté serveur, ce que PaymentGatewayResolver.resolve()
    // rejette avec IllegalArgumentException (500) — FedaPay ne s'ouvrait donc jamais sur web.
    return this.http.post<PaymentCheckoutResponse>(`/payments/checkout/${bookingId}`, {
      provider: 'FEDAPAY',
      customerEmail: customerEmail ?? null,
    });
  }

  /**
   * Paiement carte bancaire (Stripe), alternative à FedaPay. Contrairement à FedaPay, il n'existe
   * aucun endpoint `verify` dédié côté Stripe — la confirmation réelle passe uniquement par le
   * webhook Stripe côté serveur (StripeWebhookController, fichier protégé, non modifié ici). Les
   * pages de retour Stripe (`/v1/payments/stripe/success|cancel`) sont de simples pages HTML
   * backend, pas des routes Angular : après paiement carte, l'utilisateur quitte temporairement
   * le site avant d'y revenir manuellement (ex. via « Mes réservations »).
   */
  getStripeCheckoutUrl(
    bookingId: number,
    amount: number,
    currency: string,
    customerEmail: string,
  ): Observable<{ paymentUrl: string }> {
    return this.http.post<{ paymentUrl: string }>(`/payments/stripe/checkout/${bookingId}`, {
      amount,
      currency,
      customerEmail,
    });
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
   * Aligné sur mobile (`_monthlyRevenueProvider`, dashboard_gare_page.dart) : sert à calculer le
   * revenu du mois splitté Via Mobili (CONFIRMED) / Au guichet (OFFLINE_SALE) — jamais le forfait
   * client (`serviceFee`), voir `ticketsTotalAmount` en priorité sur `amount`/`totalPrice`.
   */
  getPartnerBookingsInRange(fromDate: string, toDate: string): Observable<BookingResponse[]> {
    const params = new HttpParams().set('fromDate', fromDate).set('toDate', toDate);
    return this.http.get<BookingResponse[]>(`${this.API_URL}/partner/my-bookings/range`, { params });
  }

  /**
   * Frais Mobili/commission et net compagnie par réservation payée — vue partenaire/gare de
   * l'équivalent admin `/admin/stats/transactions/list`. `stationId` restreint à une gare.
   */
  getPartnerTransactionsInRange(
    fromDate?: string,
    toDate?: string,
    stationId?: number,
  ): Observable<PartnerTransaction[]> {
    let params = new HttpParams();
    if (fromDate) params = params.set('fromDate', fromDate);
    if (toDate) params = params.set('toDate', toDate);
    if (stationId != null) params = params.set('stationId', String(stationId));
    return this.http.get<PartnerTransaction[]>('/bookings/partner/transactions/range', { params });
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

  /**
   * Vente directe (guichet) — aligné sur mobile (`OfflineSaleSheet`) : même DTO que
   * `createBooking`, le backend force `status = OFFLINE_SALE` et calcule le prix normalement
   * (aucun champ prix manuel côté client).
   */
  createOfflineSale(bookingData: BookingRequest): Observable<BookingResponse> {
    return this.http.post<BookingResponse>(`${this.API_URL}/partner/offline-sale`, bookingData);
  }

  /** Passagers confirmés d'un trajet (une entrée par réservation) — aligné sur `PassengersSheet` (mobile). */
  getConfirmedPassengers(tripId: number): Observable<BookingResponse[]> {
    return this.http.get<BookingResponse[]>(`${this.API_URL}/trips/${tripId}/passengers`);
  }
}
