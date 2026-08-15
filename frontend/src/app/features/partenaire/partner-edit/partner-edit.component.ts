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
