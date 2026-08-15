import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminCoupon,
  AdminCouponService,
  COUPON_TYPE_LABELS,
  CouponType,
} from '../../../core/services/coupon/admin-coupon.service';

@Component({
  selector: 'app-admin-coupons',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-coupons.html',
  styleUrl: './admin-coupons.scss',
})
export class AdminCoupons implements OnInit {
  private adminCouponService = inject(AdminCouponService);

  readonly TYPE_LABELS = COUPON_TYPE_LABELS;

  coupons = signal<AdminCoupon[]>([]);
  isLoading = signal(true);
  loadError = signal<string | null>(null);
  search = signal('');

  filteredCoupons = computed(() => {
    const term = this.search().trim().toLowerCase();
    if (!term) return this.coupons();
    return this.coupons().filter((c) => c.code.toLowerCase().includes(term));
  });

  isExpired(c: AdminCoupon): boolean {
    return !!c.expiresAt && new Date(c.expiresAt).getTime() < Date.now();
  }

  // --- Création ---
  showCreateForm = signal(false);
  newCode = signal('');
  newType = signal<CouponType>('PERCENTAGE');
  newValue = signal<number | null>(null);
  newExpiresAt = signal(''); // valeur d'un <input type="date">, vide = pas d'expiration
  createSubmitting = signal(false);
  createError = signal<string | null>(null);

  // --- Désactivation ---
  deactivatingId = signal<number | null>(null);
  actionError = signal<string | null>(null);

  ngOnInit() {
    this.loadCoupons();
  }

  loadCoupons() {
    this.isLoading.set(true);
    this.loadError.set(null);
    this.adminCouponService.list().subscribe({
      next: (coupons) => {
        this.coupons.set(coupons);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement coupons', err);
        this.loadError.set('Impossible de charger les coupons.');
        this.isLoading.set(false);
      },
    });
  }

  toggleCreateForm() {
    this.showCreateForm.update((v) => !v);
    this.createError.set(null);
    if (this.showCreateForm()) {
      this.newCode.set('');
      this.newType.set('PERCENTAGE');
      this.newValue.set(null);
      this.newExpiresAt.set('');
    }
  }

  submitCreate() {
    if (this.createSubmitting()) return;
    const code = this.newCode().trim().toUpperCase();
    const value = this.newValue();
    if (!code) {
      this.createError.set('Le code est obligatoire.');
      return;
    }
    if (value == null || value <= 0) {
      this.createError.set('La valeur doit être un nombre positif.');
      return;
    }
    if (this.newType() === 'PERCENTAGE' && value > 100) {
      this.createError.set('Un pourcentage ne peut pas dépasser 100.');
      return;
    }

    this.createSubmitting.set(true);
    this.createError.set(null);
    this.adminCouponService
      .create({
        code,
        type: this.newType(),
        value,
        expiresAt: this.newExpiresAt() ? `${this.newExpiresAt()}T23:59:00` : null,
      })
      .subscribe({
        next: (coupon) => {
          this.coupons.update((list) => [coupon, ...list]);
          this.createSubmitting.set(false);
          this.showCreateForm.set(false);
        },
        error: (err) => {
          this.createError.set(
            err?.status === 409 || err?.error?.message?.toLowerCase?.().includes('exist')
              ? 'Ce code coupon existe déjà.'
              : err?.error?.message || 'Impossible de créer ce coupon.',
          );
          this.createSubmitting.set(false);
        },
      });
  }

  deactivate(c: AdminCoupon) {
    if (this.deactivatingId() != null || !c.active) return;
    if (!confirm(`Désactiver le coupon ${c.code} ? Cette action est définitive.`)) return;

    this.actionError.set(null);
    this.deactivatingId.set(c.id);
    this.adminCouponService.deactivate(c.id).subscribe({
      next: (updated) => {
        this.coupons.update((list) => list.map((x) => (x.id === updated.id ? updated : x)));
        this.deactivatingId.set(null);
      },
      error: (err) => {
        this.actionError.set(err?.error?.message || 'Impossible de désactiver ce coupon.');
        this.deactivatingId.set(null);
      },
    });
  }
}
