import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  AdminClaim,
  AdminClaimService,
} from '../../../core/services/claim/admin-claim.service';
import {
  CLAIM_REASON_LABELS,
  CLAIM_STATUS_LABELS,
  ClaimStatus,
} from '../../../core/services/claim/claim.service';
import { AdminService } from '../../../core/services/admin/admin.service';
import { MobiliSecureUploadImgComponent } from '../../../shared/upload/mobili-secure-upload-img.component';

@Component({
  selector: 'app-admin-claims',
  standalone: true,
  imports: [CommonModule, FormsModule, MobiliSecureUploadImgComponent],
  templateUrl: './admin-claims.html',
  styleUrl: './admin-claims.scss',
})
export class AdminClaims implements OnInit {
  private adminClaimService = inject(AdminClaimService);
  private adminService = inject(AdminService);

  readonly REASON_LABELS = CLAIM_REASON_LABELS;
  readonly STATUS_LABELS = CLAIM_STATUS_LABELS;
  readonly STATUSES: ClaimStatus[] = ['RECEIVED', 'IN_PROGRESS', 'RESOLVED', 'REJECTED'];

  claims = signal<AdminClaim[]>([]);
  isLoading = signal(true);
  loadError = signal<string | null>(null);

  /** Filtre statut serveur (rechargement) — vide = toutes. */
  statusFilter = signal<ClaimStatus | ''>('');
  search = signal('');

  filteredClaims = computed(() => {
    const term = this.search().trim().toLowerCase();
    if (!term) return this.claims();
    return this.claims().filter((c) =>
      [c.message, c.booking?.reference, String(c.id)].filter(Boolean).some((v) =>
        String(v).toLowerCase().includes(term),
      ),
    );
  });

  /** Fil de traitement en cours (modale) : réponse admin (adminNote + message de clôture visible). */
  pendingHandle = signal<AdminClaim | null>(null);
  handleStatus = signal<ClaimStatus>('IN_PROGRESS');
  handleAdminNote = signal('');
  handleResolutionMessage = signal('');
  handleSubmitting = signal(false);
  handleError = signal<string | null>(null);

  ngOnInit() {
    this.loadClaims();
  }

  loadClaims() {
    this.isLoading.set(true);
    this.loadError.set(null);
    const status = this.statusFilter() || null;
    this.adminClaimService.list(status).subscribe({
      next: (claims) => {
        this.claims.set(claims);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement réclamations', err);
        this.loadError.set('Impossible de charger les réclamations.');
        this.isLoading.set(false);
      },
    });
  }

  setStatusFilter(s: ClaimStatus | '') {
    this.statusFilter.set(s);
    this.loadClaims();
  }

  statusPillClass(s: ClaimStatus): string {
    const m: Record<ClaimStatus, string> = {
      RECEIVED: 'warn',
      IN_PROGRESS: 'warn',
      RESOLVED: 'active',
      REJECTED: 'danger',
    };
    return m[s];
  }

  askHandle(c: AdminClaim) {
    this.handleError.set(null);
    this.handleStatus.set(c.status === 'RECEIVED' ? 'IN_PROGRESS' : c.status);
    this.handleAdminNote.set(c.adminNote || '');
    this.handleResolutionMessage.set(c.resolutionMessage || '');
    this.pendingHandle.set(c);
  }

  cancelHandle() {
    this.pendingHandle.set(null);
  }

  confirmHandle() {
    const c = this.pendingHandle();
    if (!c || this.handleSubmitting()) return;
    const status = this.handleStatus();
    if ((status === 'RESOLVED' || status === 'REJECTED') && !this.handleResolutionMessage().trim()) {
      this.handleError.set('Un message de clôture est requis pour résoudre ou rejeter une réclamation.');
      return;
    }
    this.handleSubmitting.set(true);
    this.handleError.set(null);
    this.adminClaimService
      .updateStatus(c.id, {
        status,
        adminNote: this.handleAdminNote().trim() || null,
        resolutionMessage: this.handleResolutionMessage().trim() || null,
      })
      .subscribe({
        next: (updated) => {
          this.claims.update((list) => list.map((x) => (x.id === updated.id ? updated : x)));
          this.handleSubmitting.set(false);
          this.pendingHandle.set(null);
        },
        error: (err) => {
          this.handleError.set(err?.error?.message || 'Impossible de mettre à jour cette réclamation.');
          this.handleSubmitting.set(false);
        },
      });
  }

  /** Tickets visés par une demande d'annulation partielle — voir mobile_app, ClaimFormPage :
   *  quand le passager ne sélectionne que certains tickets d'une résa multi-sièges, leurs IDs
   *  sont stockés en CSV dans details['ticketIds'] (Claim.detailsJson reste
   *  Record<string,string> côté backend, pas de nouveau champ de schéma). Absent ou vide =
   *  demande d'annulation de toute la réservation (comportement historique). Même convention
   *  que admin_claims_page.dart (mobilipro). */
  requestedTicketIds(c: AdminClaim): number[] {
    const raw = c.details?.['ticketIds'];
    if (!raw || !raw.trim()) return [];
    return raw
      .split(',')
      .map((s) => parseInt(s.trim(), 10))
      .filter((n) => !Number.isNaN(n));
  }

  // ====== Annulation résa/tickets (déclenchée depuis une réclamation, jamais automatique) ======
  // Raccourci vers POST /admin/bookings/{id}/cancel[-tickets] — même endpoint que mobilipro
  // (admin_claims_page.dart), aucune logique de paiement/annulation dupliquée ici.
  pendingCancel = signal<AdminClaim | null>(null);
  cancelMaxBags = signal(0);
  cancelDeclaredBags = signal(0);
  cancelSubmitting = signal(false);
  cancelError = signal<string | null>(null);
  cancelResultMessage = signal<string | null>(null);

  askCancel(c: AdminClaim) {
    if (!c.booking) return;
    this.cancelError.set(null);
    this.cancelResultMessage.set(null);
    this.cancelDeclaredBags.set(0);
    this.cancelMaxBags.set(0);
    this.pendingCancel.set(c);
    this.adminService.getBookingBaggageInfo(c.booking.bookingId).subscribe({
      next: (info) => this.cancelMaxBags.set(info.remaining),
      // Non bloquant : l'annulation reste possible, juste sans proposer de bagage cette fois-ci.
      error: () => this.cancelMaxBags.set(0),
    });
  }

  closeCancel() {
    this.pendingCancel.set(null);
  }

  incrementCancelBags() {
    if (this.cancelDeclaredBags() < this.cancelMaxBags()) {
      this.cancelDeclaredBags.update((v) => v + 1);
    }
  }

  decrementCancelBags() {
    if (this.cancelDeclaredBags() > 0) {
      this.cancelDeclaredBags.update((v) => v - 1);
    }
  }

  confirmCancel() {
    const c = this.pendingCancel();
    const booking = c?.booking;
    if (!c || !booking || this.cancelSubmitting()) return;

    this.cancelSubmitting.set(true);
    this.cancelError.set(null);
    const ticketIds = this.requestedTicketIds(c);
    const declaredBags = this.cancelDeclaredBags();
    const request$ =
      ticketIds.length > 0
        ? this.adminService.cancelTickets(booking.bookingId, ticketIds, declaredBags)
        : this.adminService.cancelBooking(booking.bookingId, declaredBags);

    request$.subscribe({
      next: (result) => {
        this.cancelSubmitting.set(false);
        this.cancelResultMessage.set(result.message);
      },
      error: (err) => {
        this.cancelError.set(err?.error?.message || 'Impossible d\'annuler cette réservation.');
        this.cancelSubmitting.set(false);
      },
    });
  }
}
