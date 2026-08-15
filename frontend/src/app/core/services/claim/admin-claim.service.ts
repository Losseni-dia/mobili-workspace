import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { ClaimReason, ClaimStatus } from './claim.service';

export interface BookingSummary {
  bookingId: number;
  reference: string;
  route: string;
  totalPrice: number;
  bookingDate: string;
  status: string;
}

/** Vue ADMIN — inclut adminNote, jamais exposée côté passager (PassengerClaimResponse). */
export interface AdminClaim {
  id: number;
  reason: ClaimReason;
  status: ClaimStatus;
  booking: BookingSummary | null;
  message: string;
  details: Record<string, string> | null;
  adminNote: string | null;
  resolutionMessage: string | null;
  createdAt: string;
  resolvedAt: string | null;
}

export interface UpdateClaimStatusRequest {
  status: ClaimStatus;
  adminNote?: string | null;
  resolutionMessage?: string | null;
}

@Injectable({ providedIn: 'root' })
export class AdminClaimService {
  private http = inject(HttpClient);

  list(status?: ClaimStatus | null): Observable<AdminClaim[]> {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    return this.http.get<AdminClaim[]>('/admin/claims', { params });
  }

  updateStatus(id: number, body: UpdateClaimStatusRequest): Observable<AdminClaim> {
    return this.http.patch<AdminClaim>(`/admin/claims/${id}/status`, body);
  }
}
