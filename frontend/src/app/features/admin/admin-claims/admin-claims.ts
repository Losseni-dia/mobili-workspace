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
}
