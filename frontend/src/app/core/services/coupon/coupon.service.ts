import { inject, Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

/**
 * Réponse brute de GET /coupons/{code}/validate — le backend renvoie une 400 (pas un champ
 * `valid: false`) si le coupon est invalide/inactif/expiré ; à catcher côté appelant.
 */
export interface CouponValidation {
  code: string;
  originalPrice: number;
  finalPrice: number;
  valid: boolean;
}

@Injectable({ providedIn: 'root' })
export class CouponService {
  private http = inject(HttpClient);

  /** `price` = montant sur lequel appliquer la réduction (sous-total sièges avant forfait). */
  validate(code: string, price: number): Observable<CouponValidation> {
    const params = new HttpParams().set('price', String(price));
    return this.http.get<CouponValidation>(`/coupons/${encodeURIComponent(code)}/validate`, { params });
  }
}
