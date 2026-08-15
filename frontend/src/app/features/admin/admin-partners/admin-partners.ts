import { Component, OnInit, signal, inject, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { forkJoin } from 'rxjs';
import {
  AdminService,
  CovoiturageSoloDriverAdminItem,
} from '../../../core/services/admin/admin.service';
import { Partner } from '../../../core/services/partners/partenaire.service';
import { MobiliSecureUploadImgComponent } from '../../../shared/upload/mobili-secure-upload-img.component';

@Component({
  selector: 'app-admin-partners',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, MobiliSecureUploadImgComponent],
  templateUrl: './admin-partners.html',
  styleUrl: './admin-partners.scss',
})
export class AdminPartners implements OnInit {
  private adminService = inject(AdminService);

  readonly IMAGE_BASE_URL = this.adminService.IMAGE_BASE_URL;

  partners = signal<Partner[]>([]);
  isLoading = signal<boolean>(true);
  search = signal('');

  /** Compagnies transport (lignes, partenariat classique), hors partenaire pool covoiturage. */
  publicPartners = computed(() => this.partners().filter((p) => !p.covoiturageSoloPool));

  /** Filtrage libre sur le nom/email de la compagnie. */
  filteredPartners = computed(() => {
    const term = this.search().trim().toLowerCase();
    if (!term) return this.publicPartners();
    return this.publicPartners().filter((p) =>
      [p.name, p.email].filter(Boolean).some((v) => String(v).toLowerCase().includes(term)),
    );
  });

  /** Inscriptions chauffeur covoiturage particulier (profil pool). */
  covoiturageSoloDrivers = signal<CovoiturageSoloDriverAdminItem[]>([]);

  /** Ligne (compagnie ou chauffeur covoit.) en cours de bascule statut — état de chargement. */
  statusSavingId = signal<number | null>(null);
  statusError = signal<string | null>(null);

  /** Partenaire en cours de rejet — remplace window.prompt par une modale stylée avec validation. */
  pendingReject = signal<Partner | null>(null);
  rejectReason = signal('');
  rejectSubmitting = signal(false);
  rejectError = signal<string | null>(null);

  ngOnInit() {
    this.loadPartners();
  }

  loadPartners() {
    forkJoin({
      partners: this.adminService.getAllPartnersForAdmin(),
      drivers: this.adminService.getCovoiturageSoloDrivers(),
    }).subscribe({
      next: ({ partners, drivers }) => {
        this.partners.set(partners);
        this.covoiturageSoloDrivers.set(drivers);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement partenaires / chauffeurs covoit.', err);
        this.isLoading.set(false);
      },
    });
  }

  kycLabel(s: string | null | undefined): string {
    if (!s) return '—';
    const m: Record<string, string> = {
      NONE: 'Non transmis',
      PENDING: 'En attente',
      APPROVED: 'Validé',
      REJECTED: 'Refusé',
      EXPIRED: 'CNI expirée',
    };
    return m[s] ?? s;
  }

  /** Modificateur visuel du badge KYC (couleur selon statut). */
  kycPillClass(s: string | null | undefined): string {
    if (!s) return 'kyc-pill--neutral';
    const m: Record<string, string> = {
      APPROVED: 'kyc-pill--ok',
      PENDING: 'kyc-pill--pending',
      REJECTED: 'kyc-pill--bad',
      EXPIRED: 'kyc-pill--bad',
      NONE: 'kyc-pill--neutral',
    };
    return m[s] ?? 'kyc-pill--neutral';
  }

  /** PENDING (ou REJECTED, pour permettre un rattrapage) : pas encore approuvé au sens métier. */
  isPending(p: Partner): boolean {
    return p.approvalStatus === 'PENDING' || p.approvalStatus === 'REJECTED';
  }

  /**
   * Approuve un partenaire en attente. Distinct de `togglePartner` : seul ce bouton met
   * `approvalStatus` à APPROVED — brancher « Approuver » sur `togglePartnerStatus` laissait
   * un partenaire `enabled=true` mais `approvalStatus=PENDING` en base (bug corrigé ici).
   */
  approvePartner(id: number) {
    if (!window.confirm('Approuver ce partenaire ? Il pourra publier des trajets immédiatement.')) {
      return;
    }
    this.adminService.approvePartner(id).subscribe({
      next: () => {
        this.partners.update((list) =>
          list.map((p) =>
            p.id === id ? { ...p, enabled: true, approvalStatus: 'APPROVED', rejectionReason: null } : p,
          ),
        );
      },
      error: (err) => console.error("Erreur lors de l'approbation du partenaire", err),
    });
  }

  askReject(p: Partner) {
    this.rejectError.set(null);
    this.rejectReason.set('');
    this.pendingReject.set(p);
  }

  cancelReject() {
    this.pendingReject.set(null);
  }

  confirmReject() {
    const p = this.pendingReject();
    const reason = this.rejectReason().trim();
    if (!p || this.rejectSubmitting()) return;
    if (!reason) {
      this.rejectError.set('Le motif de rejet est obligatoire.');
      return;
    }
    this.rejectSubmitting.set(true);
    this.rejectError.set(null);
    this.adminService.rejectPartner(p.id, reason).subscribe({
      next: () => {
        this.partners.update((list) =>
          list.map((x) =>
            x.id === p.id
              ? { ...x, enabled: false, approvalStatus: 'REJECTED', rejectionReason: reason }
              : x,
          ),
        );
        this.rejectSubmitting.set(false);
        this.pendingReject.set(null);
      },
      error: (err) => {
        this.rejectError.set(err?.error?.message || 'Impossible de rejeter ce partenaire.');
        this.rejectSubmitting.set(false);
      },
    });
  }

  /** Suspendre / réactiver un partenaire DÉJÀ approuvé — ne touche jamais approvalStatus. */
  togglePartner(p: Partner) {
    if (this.statusSavingId() != null) return;
    const verb = p.enabled ? 'suspendre' : 'réactiver';
    if (!confirm(`Confirmer : ${verb} la compagnie ${p.name} ?`)) return;

    this.statusError.set(null);
    this.statusSavingId.set(p.id);
    this.adminService.togglePartnerStatus(p.id).subscribe({
      next: () => {
        this.partners.update((list) =>
          list.map((x) => (x.id === p.id ? { ...x, enabled: !x.enabled } : x)),
        );
        this.statusSavingId.set(null);
      },
      error: (err) => {
        this.statusError.set(err?.error?.message || `Impossible de ${verb} cette compagnie.`);
        this.statusSavingId.set(null);
      },
    });
  }

  /** Suspendre / réactiver un compte conducteur covoit. (même API que la page Utilisateurs). */
  toggleDriverAccount(d: CovoiturageSoloDriverAdminItem) {
    if (this.statusSavingId() != null) return;
    const nextEnabled = !d.enabled;
    const verb = nextEnabled ? 'réactiver' : 'suspendre';
    const name = `${d.firstname || ''} ${d.lastname || ''}`.trim() || d.email;
    if (!confirm(`Confirmer : ${verb} le compte de ${name} ?`)) return;

    this.statusError.set(null);
    this.statusSavingId.set(d.id);
    this.adminService.toggleUserStatus(d.id, nextEnabled).subscribe({
      next: () => {
        this.covoiturageSoloDrivers.update((list) =>
          list.map((u) => (u.id === d.id ? { ...u, enabled: nextEnabled } : u)),
        );
        this.statusSavingId.set(null);
      },
      error: (err) => {
        this.statusError.set(err?.error?.message || `Impossible de ${verb} ce compte.`);
        this.statusSavingId.set(null);
      },
    });
  }
}
