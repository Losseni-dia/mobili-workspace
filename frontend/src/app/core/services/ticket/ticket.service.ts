import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { NotificationService } from '../notification/notification.service';

/** Aligné sur PartnerTicketResponse (backend) — vue gare/partenaire, PAS la vue passager. */
export interface PartnerTicket {
  id: number;
  ticketNumber: string;
  passengerName: string;
  route: string;
  stationName: string;
  bookingDate: string;
  /** Part du prix passager (inclut le forfait client) — jamais affiché côté gare/partenaire. */
  amountPaid: number;
  /**
   * Vente brute compagnie pour ce ticket (transport + bagages, jamais le forfait client).
   * `null` sur les tickets antérieurs à la décomposition tarifaire : retomber sur `amountPaid`.
   */
  grossAmount: number | null;
  /** VALIDÉ / UTILISÉ / ANNULÉ / ARRIVÉ. */
  status: string;
  seatNumber: string;
  scanned: boolean;
}

export interface TicketResponse {
  tripId?: number;
  ticketNumber: string;
  passengerFullName: string;
  qrCodeData: string;
  departureCity: string;
  arrivalCity: string;
  departureDateTime: string;
  vehiculePlateNumber: string;
  price: number;
  status: string;
  partnerName: string;
  seatNumber: string;
}

@Injectable({ providedIn: 'root' })
export class TicketService {
  private http = inject(HttpClient);
  private notificationService = inject(NotificationService);

  // On utilise le même préfixe que tes autres services
  private readonly API_URL = '/tickets';

  /**
   * Récupère tous les tickets d'un utilisateur
   */
  getTicketsByUserId(userId: number): Observable<TicketResponse[]> {
    return this.http.get<TicketResponse[]>(`${this.API_URL}/user/${userId}`).pipe(
      catchError(() => {
        this.notificationService.show('Impossible de charger les tickets pour le moment.', 'error');
        return of([]); // Renvoie une liste vide en cas d'erreur pour éviter de faire planter l'UI
      }),
    );
  }

  /**
   * Récupère les détails d'un ticket spécifique
   */
  getTicketById(ticketId: number): Observable<TicketResponse> {
    return this.http.get<TicketResponse>(`${this.API_URL}/${ticketId}`);
  }

  /**
   * Annuler un ticket
   */
  cancelTicket(ticketId: number): Observable<void> {
    return this.http.patch<void>(`${this.API_URL}/${ticketId}/cancel`, {});
  }

  verifyTicket(ticketNumber: string): Observable<TicketResponse> {
    return this.http.patch<TicketResponse>(`${this.API_URL}/verify/${ticketNumber}`, {});
  }

  /**
   * Tickets de la compagnie (ou de la gare connectée) sur une période — vue gare/partenaire,
   * jamais les réservations. `stationId` optionnel : restreint à une gare précise.
   */
  getPartnerTicketsInRange(
    fromDate?: string,
    toDate?: string,
    stationId?: number,
    search?: string,
  ): Observable<PartnerTicket[]> {
    let params = new HttpParams();
    if (fromDate) params = params.set('fromDate', fromDate);
    if (toDate) params = params.set('toDate', toDate);
    if (stationId != null) params = params.set('stationId', String(stationId));
    if (search) params = params.set('search', search);
    return this.http.get<PartnerTicket[]>(`${this.API_URL}/partner/my-tickets/range`, { params });
  }
}
