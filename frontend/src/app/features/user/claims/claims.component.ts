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
import { NotificationService } from '../../../core/services/notification/notification.service';
import { TicketResponse, TicketService } from '../../../core/services/ticket/ticket.service';
import { MobiliSecureUploadImgComponent } from '../../../shared/upload/mobili-secure-upload-img.component';

/** Un ticket déjà annulé ou déjà scanné à l'embarquement ne peut pas être (re)proposé à
 *  l'annulation — même règle que mobile_app (Ticket.isCancellable). */
function isTicketCancellable(t: TicketResponse): boolean {
  const s = (t.status || '').toUpperCase();
  return s !== 'ANNULÉ' && s !== 'CANCELLED' && s !== 'UTILISÉ' && s !== 'UTILISE';
}

/** Taille max côté UI — alignée sur mobili.backend.upload.max-bytes-per-file (12 Mo), le serveur revalide de toute façon. */
const MAX_ATTACHMENT_BYTES = 12 * 1024 * 1024;
const ALLOWED_ATTACHMENT_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

/** Réclamations voyageur — parité mobile_app (claim_form_page.dart, my_claims_page.dart). */
@Component({
  selector: 'app-claims',
  standalone: true,
  imports: [CommonModule, FormsModule, MobiliSecureUploadImgComponent],
  templateUrl: './claims.component.html',
  styleUrl: './claims.component.scss',
})
export class ClaimsComponent implements OnInit {
  private claimService = inject(ClaimService);
  private bookingService = inject(BookingService);
  private ticketService = inject(TicketService);
  private authService = inject(AuthService);
  private route = inject(ActivatedRoute);
  private toast = inject(NotificationService);

  attachment = signal<File | null>(null);
  attachmentError = signal<string | null>(null);

  readonly reasonLabels = CLAIM_REASON_LABELS;
  readonly statusLabels = CLAIM_STATUS_LABELS;
  readonly reasons = Object.keys(CLAIM_REASON_LABELS) as ClaimReason[];

  claims = signal<PassengerClaim[]>([]);
  isLoading = signal(false);
  loadError = signal<string | null>(null);

  /** Arrivée depuis une notification de changement de statut — scrolle et met en évidence la
   *  réclamation concernée, même principe que MyClaimsPage.highlightClaimId (mobile_app). */
  highlightedClaimId = signal<number | null>(null);

  bookings = signal<BookingResponse[]>([]);

  showNewForm = signal(false);
  reason = signal<ClaimReason>('OTHER');
  /** true quand le motif arrive préréglé par lien (ex. « Annuler » depuis Mes réservations) —
   *  verrouille le select pour ne pas laisser l'utilisateur dévier du motif attendu par ce lien. */
  reasonLocked = signal(false);
  bookingId = signal<number | null>(null);
  message = signal('');
  submitting = signal(false);
  createError = signal<string | null>(null);

  needsBooking = computed(() => claimReasonRequiresBooking(this.reason()));

  /** Réservation sélectionnée — utile pour connaître numberOfSeats/extraHoldBags sans
   *  re-chercher dans bookings() partout. */
  selectedBooking = computed<BookingResponse | null>(
    () => this.bookings().find((b) => b.id === this.bookingId()) ?? null,
  );

  /** Uniquement pour le motif annulation sur une résa multi-sièges : tickets de la réservation
   *  sélectionnée, pour permettre de n'en annuler qu'une partie — même parité que mobile_app
   *  (ClaimFormPage._bookingTickets). null tant qu'aucune résa multi-sièges n'est sélectionnée. */
  bookingTickets = signal<TicketResponse[] | null>(null);
  loadingTickets = signal(false);
  selectedTicketIds = signal<Set<number>>(new Set());

  /** Bagages soute que le voyageur demande à faire rembourser — une DEMANDE pour l'admin
   *  (jamais exécutée automatiquement, voir BookingService.refundDeclaredBaggage côté backend).
   *  Par défaut, tout le quota enregistré ("j'annule tout"), l'utilisateur peut le réduire. */
  declaredBags = signal(0);

  private loadTicketsForSelectedBooking(): void {
    const booking = this.selectedBooking();
    this.declaredBags.set(booking?.extraHoldBags ?? 0);
    if (!booking || this.reason() !== 'CANCELLATION' || booking.numberOfSeats <= 1) {
      this.bookingTickets.set(null);
      this.selectedTicketIds.set(new Set());
      return;
    }
    this.loadingTickets.set(true);
    this.ticketService.getByBooking(booking.id).subscribe({
      next: (tickets) => {
        this.bookingTickets.set(tickets || []);
        // Tout sélectionné par défaut = "annuler toute la réservation" (comportement
        // historique) — l'utilisateur décoche ce qu'il veut garder.
        this.selectedTicketIds.set(
          new Set((tickets || []).filter(isTicketCancellable).map((t) => t.id!)),
        );
        this.loadingTickets.set(false);
      },
      error: () => {
        this.bookingTickets.set(null);
        this.selectedTicketIds.set(new Set());
        this.loadingTickets.set(false);
      },
    });
  }

  onBookingSelected(id: number): void {
    this.bookingId.set(id);
    this.loadTicketsForSelectedBooking();
  }

  onReasonChange(reason: ClaimReason): void {
    this.reason.set(reason);
    this.bookingId.set(null);
    this.bookingTickets.set(null);
    this.selectedTicketIds.set(new Set());
    this.declaredBags.set(0);
  }

  toggleTicket(id: number): void {
    this.selectedTicketIds.update((set) => {
      const next = new Set(set);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  cancellableTickets = computed(() => (this.bookingTickets() || []).filter(isTicketCancellable));

  incrementBags(): void {
    const max = this.selectedBooking()?.extraHoldBags ?? 0;
    if (this.declaredBags() < max) this.declaredBags.update((v) => v + 1);
  }

  decrementBags(): void {
    if (this.declaredBags() > 0) this.declaredBags.update((v) => v - 1);
  }

  ngOnInit(): void {
    const prefClaim = this.route.snapshot.queryParamMap.get('claimId');
    if (prefClaim) {
      const id = Number(prefClaim);
      if (!Number.isNaN(id)) this.highlightedClaimId.set(id);
    }
    this.loadClaims();
    const prefBooking = this.route.snapshot.queryParamMap.get('bookingId');
    if (prefBooking) {
      const id = Number(prefBooking);
      if (!Number.isNaN(id)) {
        this.bookingId.set(id);
        // Le lien « Signaler » ne passe pas de `reason` (comportement historique : motif
        // « Remboursement » par défaut) ; le lien « Annuler » passe `reason=CANCELLATION`.
        const prefReason = this.route.snapshot.queryParamMap.get('reason') as ClaimReason | null;
        if (prefReason && this.reasons.includes(prefReason)) {
          this.reason.set(prefReason);
          this.reasonLocked.set(true);
        } else {
          this.reason.set('REFUND_REQUEST');
        }
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
        this.scrollToHighlighted();
      },
      error: (e) => {
        this.loadError.set(e?.error?.message || 'Impossible de charger vos réclamations.');
        this.isLoading.set(false);
      },
    });
  }

  private scrollToHighlighted(): void {
    const id = this.highlightedClaimId();
    if (id == null) return;
    setTimeout(() => {
      document.getElementById(`claim-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      setTimeout(() => this.highlightedClaimId.set(null), 3000);
    }, 0);
  }

  openNewForm(): void {
    this.createError.set(null);
    this.reasonLocked.set(false);
    this.showNewForm.set(true);
  }

  cancelNewForm(): void {
    this.showNewForm.set(false);
  }

  /** ticketIds : absent (résa entière) sauf si l'utilisateur a désélectionné au moins un
   *  siège annulable. bagsToCancel : nombre de bagages demandés, absent si aucun déclaré.
   *  Même parité que mobile_app (ClaimFormPage._claimDetails). */
  private buildClaimDetails(): Record<string, string> | undefined {
    const details: Record<string, string> = {};
    const tickets = this.bookingTickets();
    if (tickets && tickets.length > 0) {
      const cancellableIds = this.cancellableTickets().map((t) => t.id!);
      if (this.selectedTicketIds().size < cancellableIds.length) {
        details['ticketIds'] = Array.from(this.selectedTicketIds()).join(',');
      }
    }
    if (this.reason() === 'CANCELLATION' && this.declaredBags() > 0) {
      details['bagsToCancel'] = String(this.declaredBags());
    }
    return Object.keys(details).length > 0 ? details : undefined;
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
    const attachment = this.attachment();
    this.claimService
      .create({
        reason: this.reason(),
        bookingId: this.needsBooking() ? this.bookingId() : null,
        message: msg,
        details: this.buildClaimDetails(),
      })
      .subscribe({
        next: (claim) => {
          const finish = (finalClaim: PassengerClaim) => {
            this.submitting.set(false);
            this.message.set('');
            this.bookingId.set(null);
            this.reason.set('OTHER');
            this.reasonLocked.set(false);
            this.attachment.set(null);
            this.bookingTickets.set(null);
            this.selectedTicketIds.set(new Set());
            this.declaredBags.set(0);
            this.showNewForm.set(false);
            this.claims.update((list) => [finalClaim, ...list]);
            this.toast.show('Votre réclamation a bien été envoyée.', 'success');
          };
          // Deuxième appel optionnel : la preuve n'empêche jamais l'envoi du texte de la
          // réclamation si son upload échoue (juste un avertissement, pas de perte du message).
          if (attachment) {
            this.claimService.addAttachment(claim.id, attachment).subscribe({
              next: (withAttachment) => finish(withAttachment),
              error: () => {
                this.toast.show(
                  "Réclamation envoyée, mais l'ajout de la pièce jointe a échoué.",
                  'error',
                );
                finish(claim);
              },
            });
          } else {
            finish(claim);
          }
        },
        error: (e) => {
          this.createError.set(e?.error?.message || "Impossible d'envoyer cette réclamation.");
          this.submitting.set(false);
        },
      });
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0] ?? null;
    this.attachmentError.set(null);
    if (!file) {
      this.attachment.set(null);
      return;
    }
    if (!ALLOWED_ATTACHMENT_TYPES.includes(file.type)) {
      this.attachmentError.set('Formats acceptés : JPEG, PNG, WebP ou PDF.');
      input.value = '';
      this.attachment.set(null);
      return;
    }
    if (file.size > MAX_ATTACHMENT_BYTES) {
      this.attachmentError.set('Fichier trop volumineux (max 12 Mo).');
      input.value = '';
      this.attachment.set(null);
      return;
    }
    this.attachment.set(file);
  }

  clearAttachment(): void {
    this.attachment.set(null);
    this.attachmentError.set(null);
  }

  bookingLabel(b: BookingResponse): string {
    return `#${b.reference} — ${b.departureCity} → ${b.arrivalCity}`;
  }
}
