import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { NotificationService } from '../notification/notification.service';

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
}
