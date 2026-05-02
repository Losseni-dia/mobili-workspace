import { Component, OnInit, signal, inject, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
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
  imports: [CommonModule, RouterLink, MobiliSecureUploadImgComponent],
  templateUrl: './admin-partners.html',
  styleUrl: './admin-partners.scss',
})
export class AdminPartners implements OnInit {
  private adminService = inject(AdminService);

  readonly IMAGE_BASE_URL = this.adminService.IMAGE_BASE_URL;

  partners = signal<Partner[]>([]);
  isLoading = signal<boolean>(true);

  /** Compagnies transport (lignes, partenariat classique), hors partenaire pool covoiturage. */
  publicPartners = computed(() => this.partners().filter((p) => !p.covoiturageSoloPool));

  /** Inscriptions chauffeur covoiturage particulier (profil pool). */
  covoiturageSoloDrivers = signal<CovoiturageSoloDriverAdminItem[]>([]);

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

  togglePartner(id: number) {
    this.adminService.togglePartnerStatus(id).subscribe({
      next: () => {
        this.partners.update((list) =>
          list.map((p) => (p.id === id ? { ...p, enabled: !p.enabled } : p)),
        );
      },
      error: (err) => console.error('Erreur lors du switch de statut', err),
    });
  }

  /** Suspendre / réactiver un compte conducteur covoit. (même API que la page Utilisateurs). */
  toggleDriverAccount(d: CovoiturageSoloDriverAdminItem) {
    const nextEnabled = !d.enabled;
    this.adminService.toggleUserStatus(d.id, nextEnabled).subscribe({
      next: () => {
        this.covoiturageSoloDrivers.update((list) =>
          list.map((u) => (u.id === d.id ? { ...u, enabled: nextEnabled } : u)),
        );
      },
      error: (err) => console.error('Erreur statut compte conducteur', err),
    });
  }
}
