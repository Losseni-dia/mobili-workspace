import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import {
  CLAIM_REASON_LABELS,
  CLAIM_STATUS_LABELS,
  ClaimReason,
  ClaimService,
  claimReasonRequiresBooking,
  PassengerClaim,
} from '../../../core/services/claim/claim.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';

/** Réclamations voyageur — parité mobile_app (claim_form_page.dart, my_claims_page.dart). */
@Component({
  selector: 'app-claims',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './claims.component.html',
  styleUrl: './claims.component.scss',
})
export class ClaimsComponent implements OnInit {
  private claimService = inject(ClaimService);
  private bookingService = inject(BookingService);
  private authService = inject(AuthService);
  private route = inject(ActivatedRoute);

  readonly reasonLabels = CLAIM_REASON_LABELS;
  readonly statusLabels = CLAIM_STATUS_LABELS;
  readonly reasons = Object.keys(CLAIM_REASON_LABELS) as ClaimReason[];

  claims = signal<PassengerClaim[]>([]);
  isLoading = signal(false);
  loadError = signal<string | null>(null);

  bookings = signal<BookingResponse[]>([]);

  showNewForm = signal(false);
  reason = signal<ClaimReason>('OTHER');
  bookingId = signal<number | null>(null);
  message = signal('');
  submitting = signal(false);
  createError = signal<string | null>(null);

  needsBooking = computed(() => claimReasonRequiresBooking(this.reason()));

  ngOnInit(): void {
    this.loadClaims();
    const prefBooking = this.route.snapshot.queryParamMap.get('bookingId');
    if (prefBooking) {
      const id = Number(prefBooking);
      if (!Number.isNaN(id)) {
        this.bookingId.set(id);
        this.reason.set('REFUND_REQUEST');
        this.showNewForm.set(true);
      }
    }
    const user = this.authService.currentUser();
    if (user) {
      this.bookingService.getUserBookings(user.id).subscribe({
        next: (rows) => this.bookings.set(rows || []),
        error: () => this.bookings.set([]),
      });
    }
  }

  loadClaims(): void {
    const user = this.authService.currentUser();
    if (!user) return;
    this.isLoading.set(true);
    this.loadError.set(null);
    this.claimService.listMine(user.id).subscribe({
      next: (rows) => {
        this.claims.set(rows || []);
        this.isLoading.set(false);
        if (rows.length === 0) this.showNewForm.set(true);
      },
      error: (e) => {
        this.loadError.set(e?.error?.message || 'Impossible de charger vos réclamations.');
        this.isLoading.set(false);
      },
    });
  }

  openNewForm(): void {
    this.createError.set(null);
    this.showNewForm.set(true);
  }

  cancelNewForm(): void {
    this.showNewForm.set(false);
  }

  submit(): void {
    const msg = this.message().trim();
    if (!msg || this.submitting()) return;
    if (this.needsBooking() && !this.bookingId()) {
      this.createError.set('Choisissez la réservation concernée.');
      return;
    }

    this.submitting.set(true);
    this.createError.set(null);
    this.claimService
      .create({
        reason: this.reason(),
        bookingId: this.needsBooking() ? this.bookingId() : null,
        message: msg,
      })
      .subscribe({
        next: (claim) => {
          this.submitting.set(false);
          this.message.set('');
          this.bookingId.set(null);
          this.reason.set('OTHER');
          this.showNewForm.set(false);
          this.claims.update((list) => [claim, ...list]);
        },
        error: (e) => {
          this.createError.set(e?.error?.message || "Impossible d'envoyer cette réclamation.");
          this.submitting.set(false);
        },
      });
  }

  bookingLabel(b: BookingResponse): string {
    return `#${b.reference} — ${b.departureCity} → ${b.arrivalCity}`;
  }
}
