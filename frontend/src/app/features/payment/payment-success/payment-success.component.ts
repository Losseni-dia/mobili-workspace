import { Component, OnInit, OnDestroy, inject, signal, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common'; // Pour *ngIf et *ngFor
import { ActivatedRoute, Router, RouterModule } from '@angular/router'; // Pour routerLink
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';
import { of, Subject, timer } from 'rxjs';
import { catchError, switchMap, take, takeUntil } from 'rxjs/operators';


@Component({
  selector: 'app-payment-success',
  standalone: true,
  imports: [CommonModule, RouterModule], // <--- AJOUTE ÇA ICI
  templateUrl: './payment-success.component.html',
  styleUrls: ['./payment-success.component.scss'],
})
export class PaymentSuccessComponent implements OnInit, OnDestroy {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private bookingService = inject(BookingService);
  private cdr = inject(ChangeDetectorRef);
  private destroy$ = new Subject<void>();

  bookingId: number | null = null;
  loading = true;
  bookingDetails: BookingResponse | null = null;
  errorMessage: string | null = null;
  private readonly maxAttempts = 12;
  private attempts = 0;

  ngOnInit(): void {
    // FedaPay renvoie souvent seulement ?id=BOOKING_ID (sans status=approved).
    // On tente d'abord une vérification serveur (API FedaPay + confirmation + billets),
    // puis on interroge la réservation jusqu’à statut != PENDING.
    this.route.queryParams
      .pipe(take(1))
      .subscribe((params) => {
        const idParam = params['id'];
        if (!idParam) {
          this.router.navigate(['/']);
          return;
        }
        const id = Array.isArray(idParam) ? idParam[0] : idParam;
        const parsed = parseInt(String(id), 10);
        if (Number.isNaN(parsed) || parsed < 1) {
          this.router.navigate(['/']);
          return;
        }
        this.bookingId = parsed;

        this.bookingService
          .verifyFedaPayPayment(this.bookingId)
          .pipe(catchError(() => of(null)))
          .subscribe(() => this.startPollingBookingDetails());
      });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  private startPollingBookingDetails() {
    this.attempts = 0;
    timer(0, 2000)
      .pipe(
        takeUntil(this.destroy$),
        switchMap(() => {
          this.attempts += 1;
          return this.bookingService.getBookingById(this.bookingId as number);
        }),
      )
      .subscribe({
        next: (data) => this.handleBookingState(data),
        error: () => this.handlePollingError(),
      });
  }

  private handleBookingState(data: BookingResponse) {
    this.bookingDetails = data;
    if (data.status === 'PENDING' && this.attempts < this.maxAttempts) {
      return;
    }

    if (data.status === 'PENDING') {
      this.errorMessage = 'La confirmation prend plus de temps que prévu. Vérifie tes billets dans quelques instants.';
    }
    this.loading = false;
    this.destroy$.next();
    this.cdr.detectChanges();
  }

  private handlePollingError() {
    this.loading = false;
    this.errorMessage = 'Impossible de récupérer la confirmation du paiement pour le moment.';
    this.destroy$.next();
    this.cdr.detectChanges();
  }

  loadBookingDetails() {
    if (!this.bookingId) return;

    this.bookingService.getBookingById(this.bookingId).subscribe({
      next: (data) => {
        this.handleBookingState(data);
      },
      error: () => this.handlePollingError(),
    });
  }
}
