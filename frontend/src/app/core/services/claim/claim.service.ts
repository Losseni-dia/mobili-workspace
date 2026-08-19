import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

/** Aligné sur l'enum backend ClaimReason. */
export type ClaimReason = 'REFUND_REQUEST' | 'CANCELLATION' | 'DELAY' | 'DRIVER_ISSUE' | 'LOST_ITEM' | 'OTHER';

/** Aligné sur ClaimStatus (backend). */
export type ClaimStatus = 'RECEIVED' | 'IN_PROGRESS' | 'RESOLVED' | 'REJECTED';

export const CLAIM_REASON_LABELS: Record<ClaimReason, string> = {
  REFUND_REQUEST: 'Demande de remboursement',
  CANCELLATION: 'Annulation',
  DELAY: 'Retard',
  DRIVER_ISSUE: 'Problème avec le chauffeur',
  LOST_ITEM: 'Objet perdu',
  OTHER: 'Autre',
};

export const CLAIM_STATUS_LABELS: Record<ClaimStatus, string> = {
  RECEIVED: 'Reçue',
  IN_PROGRESS: 'En cours de traitement',
  RESOLVED: 'Résolue',
  REJECTED: 'Rejetée',
};

/**
 * `true` si une réservation doit obligatoirement être associée à la réclamation — revalidé côté
 * serveur de toute façon (ClaimReason.requiresBooking()), répliqué ici juste pour l'UI (afficher/
 * masquer le sélecteur de réservation).
 */
export function claimReasonRequiresBooking(reason: ClaimReason): boolean {
  return reason === 'REFUND_REQUEST' || reason === 'CANCELLATION' || reason === 'DELAY' || reason === 'DRIVER_ISSUE';
}

export interface CreateClaimRequest {
  reason: ClaimReason;
  bookingId?: number | null;
  message: string;
  details?: Record<string, string>;
}

/**
 * Aligné sur PassengerClaimResponse (backend) — jamais adminNote, réservé à la vue admin.
 * `booking` = BookingSummaryResponse, champs exacts non garantis ici : accès défensif côté UI.
 */
export interface PassengerClaim {
  id: number;
  reason: ClaimReason;
  status: ClaimStatus;
  booking: ({ id: number } & Record<string, unknown>) | null;
  message: string;
  details: Record<string, string> | null;
  resolutionMessage: string | null;
  createdAt: string;
  resolvedAt: string | null;
  attachmentPath: string | null;
  attachmentOriginalName: string | null;
  attachmentContentType: string | null;
}

@Injectable({ providedIn: 'root' })
export class ClaimService {
  private http = inject(HttpClient);

  create(body: CreateClaimRequest): Observable<PassengerClaim> {
    return this.http.post<PassengerClaim>('/claims', body);
  }

  listMine(userId: number): Observable<PassengerClaim[]> {
    return this.http.get<PassengerClaim[]>(`/claims/mine/${userId}`);
  }

  /** Étape optionnelle après create() : joint une preuve (image ou PDF) à une réclamation existante. */
  addAttachment(claimId: number, file: File): Observable<PassengerClaim> {
    const form = new FormData();
    form.append('file', file);
    return this.http.post<PassengerClaim>(`/claims/${claimId}/attachment`, form);
  }
}
