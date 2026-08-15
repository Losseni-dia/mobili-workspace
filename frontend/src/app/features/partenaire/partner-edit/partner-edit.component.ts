import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { PartenaireService, Partner } from '../../../core/services/partners/partenaire.service';
import { Location } from '@angular/common';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { extractApiErrorMessage } from '../../../core/utils/api-error.util';

@Component({
  selector: 'app-partner-edit',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './partner-edit.component.html',
  styleUrls: ['./partner-edit.component.scss'],
})
export class PartnerEditComponent implements OnInit {
  private fb = inject(FormBuilder);
  private partenaireService = inject(PartenaireService);
  private router = inject(Router);
  private notification = inject(NotificationService);

  isLoading = signal(false);
  partnerId = signal<number | null>(null);
  logoPreview = signal<string | null>(null);
  /** Code partenaire (inscription gare) — lecture seule, renvoyé par l’API. */
  registrationCode = signal<string | null>(null);
  /** Fin du chargement GET /my-company (succès ou erreur). */
  loadComplete = signal(false);
  copyFeedback = signal(false);
  selectedFile: File | null = null;

  /**
   * PENDING/APPROVED/REJECTED — resoumission KYC affichée uniquement si REJECTED. Pas d'endpoint
   * dédié côté backend : c'est le même PUT /partners/{id} que la mise à jour de profil, avec les
   * parts kycFront/kycBack en plus ; le backend repasse automatiquement approvalStatus à PENDING.
   */
  approvalStatus = signal<string | null>(null);
  rejectionReason = signal<string | null>(null);
  kycFrontFile: File | null = null;
  kycBackFile: File | null = null;
  kycFrontName = signal<string | null>(null);
  kycBackName = signal<string | null>(null);
  kycError = signal<string | null>(null);

  // Formulaire réactif
  partnerForm = this.fb.group({
    name: ['', [Validators.required, Validators.minLength(3)]],
    email: ['', [Validators.required, Validators.email]],
    phone: ['', [Validators.required]],
    // Optionnel, comme à l'inscription (PartnerRegisterDTO/PartnerProfileDTO backend n'ont
    // aucune contrainte sur ce champ) — required ici était un oubli, pas une règle métier.
    businessNumber: [''],
  });

  private location = inject(Location);

  onCancel() {
    this.location.back();
  }

  copyRegistrationCode() {
    const code = this.registrationCode();
    if (!code) return;
    void navigator.clipboard.writeText(code).then(() => {
      this.copyFeedback.set(true);
      setTimeout(() => this.copyFeedback.set(false), 2000);
    });
  }

  ngOnInit() {
    this.loadPartnerData();
  }

  loadPartnerData() {
    this.isLoading.set(true);
    this.partenaireService.getMyPartnerInfo().subscribe({
      next: (partner: Partner) => {
        this.partnerId.set(partner.id);

        // 💡 On remplit le formulaire.
        // Si businessNumber s'appelle 'rccm' en base, assure-toi que les noms matchent.
        this.partnerForm.patchValue({
          name: partner.name,
          email: partner.email,
          phone: partner.phone,
          businessNumber: partner.businessNumber,
        });

        if (partner.logoUrl) {
          // 💡 Correction de l'URL : on ajoute 'partners/' car c'est ton dossier YAML
         this.logoPreview.set(`${this.partenaireService.IMAGE_BASE_URL}${partner.logoUrl}`);
        }

        this.registrationCode.set(
          partner.registrationCode?.trim() ? partner.registrationCode.trim() : null,
        );
        this.approvalStatus.set(partner.approvalStatus ?? null);
        this.rejectionReason.set(partner.rejectionReason ?? null);

        this.isLoading.set(false);
        this.loadComplete.set(true);
      },
      error: (err) => {
        console.error('Erreur chargement partenaire', err);
        this.isLoading.set(false);
        this.loadComplete.set(true);
      },
    });
  }

  onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (file) {
      this.selectedFile = file;
      // Création d'un aperçu local immédiat
      const reader = new FileReader();
      reader.onload = () => this.logoPreview.set(reader.result as string);
      reader.readAsDataURL(file);
    }
  }

  onKycFrontSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (file) {
      this.kycFrontFile = file;
      this.kycFrontName.set(file.name);
    }
  }

  onKycBackSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (file) {
      this.kycBackFile = file;
      this.kycBackName.set(file.name);
    }
  }

  /** Formulaire minimal dédié : ne touche que les documents, pas le reste du profil compagnie. */
  submitKycResubmission() {
    if (!this.partnerId() || (!this.kycFrontFile && !this.kycBackFile)) return;
    this.kycError.set(null);
    this.isLoading.set(true);

    const formData = new FormData();
    if (this.kycFrontFile) formData.append('kycFront', this.kycFrontFile);
    if (this.kycBackFile) formData.append('kycBack', this.kycBackFile);

    this.partenaireService.updatePartner(this.partnerId()!, formData).subscribe({
      next: (partner) => {
        this.approvalStatus.set(partner.approvalStatus ?? 'PENDING');
        this.rejectionReason.set(null);
        this.kycFrontFile = null;
        this.kycBackFile = null;
        this.kycFrontName.set(null);
        this.kycBackName.set(null);
        this.isLoading.set(false);
        this.notification.show('Dossier renvoyé pour validation.', 'success');
      },
      error: (err) => {
        console.error('Erreur resoumission KYC', err);
        this.kycError.set(extractApiErrorMessage(err, 'Impossible de renvoyer le dossier.'));
        this.isLoading.set(false);
      },
    });
  }

  onSubmit() {
    if (this.partnerForm.invalid || !this.partnerId()) return;
    this.isLoading.set(true);

    const formData = new FormData();
    // Préparation du DTO JSON
    const partnerBlob = new Blob([JSON.stringify(this.partnerForm.value)], {
      type: 'application/json',
    });

    formData.append('partner', partnerBlob);
    if (this.selectedFile) {
      formData.append('logo', this.selectedFile); // 💡 Clé "logo" pour matcher ton @RequestPart
    }

    this.partenaireService.updatePartner(this.partnerId()!, formData).subscribe({
      next: () => {
        this.notification.show('Profil compagnie mis à jour.', 'success');
        this.router.navigate(['/partenaire/dashboard']);
      },
      error: (err) => {
        console.error('Erreur MAJ partenaire', err);
        this.notification.show(
          extractApiErrorMessage(err, 'Impossible de mettre à jour le profil compagnie.'),
          'error',
        );
        this.isLoading.set(false);
      },
    });
  }
}
