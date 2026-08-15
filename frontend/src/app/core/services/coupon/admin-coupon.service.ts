import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

/** Aligné sur l'enum backend CouponType. */
export type CouponType = 'PERCENTAGE' | 'FIXED_AMOUNT';

export const COUPON_TYPE_LABELS: Record<CouponType, string> = {
  PERCENTAGE: 'Pourcentage',
  FIXED_AMOUNT: 'Montant fixe',
};

export interface AdminCoupon {
  id: number;
  code: string;
  type: CouponType;
  value: number;
  active: boolean;
  expiresAt: string | null;
}

export interface CreateCouponRequest {
  code: string;
  type: CouponType;
  value: number;
  /** ISO local (ex. `2026-12-31T23:59:00`) — null/absent = pas d'expiration. */
  expiresAt?: string | null;
}

@Injectable({ providedIn: 'root' })
export class AdminCouponService {
  private http = inject(HttpClient);

  list(): Observable<AdminCoupon[]> {
    return this.http.get<AdminCoupon[]>('/admin/coupons');
  }

  create(body: CreateCouponRequest): Observable<AdminCoupon> {
    return this.http.post<AdminCoupon>('/admin/coupons', body);
  }

  deactivate(id: number): Observable<AdminCoupon> {
    return this.http.patch<AdminCoupon>(`/admin/coupons/${id}/deactivate`, {});
  }
}
