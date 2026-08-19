import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';

import { NotificationService } from '../../../core/services/notification/notification.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { extractApiErrorMessage } from '../../../core/utils/api-error.util';

@Component({
  selector: 'app-register-partner',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule],
  templateUrl: './register-partner.component.html',
  styleUrls: ['./register-partner.component.scss'],
})
export class RegisterPartnerComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);
  private notification = inject(NotificationService);

  isLoading = signal(false);
  selectedLogo: File | null = null;
  logoPreview = signal<string | null>(null);
  selectedKycFront: File | null = null;
  selectedKycBack: File | null = null;

  // email/companyEmail optionnels + phone (responsable) obligatoire — aligné sur
  // RegisterCompanyPublicDTO côté backend, pas sur les anciennes règles UI-only.
  signupForm = this.fb.nonNullable.group({
    firstname: ['', [Validators.required]],
    lastname: ['', [Validators.required]],
    login: ['', [Validators.required, Validators.minLength(3)]],
    email: ['', [Validators.email]],
    phone: ['', [Validators.required, Validators.minLength(8), Validators.maxLength(20)]],
    password: ['', [Validators.required, Validators.minLength(6)]],
    confirmPassword: ['', [Validators.required]],
    companyName: ['', [Validators.required]],
    companyEmail: ['', [Validators.email]],
    companyPhone: ['', [Validators.required, Validators.minLength(8), Validators.maxLength(20)]],
    businessNumber: [''],
  });

  onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    this.selectedLogo = file;
    const reader = new FileReader();
    reader.onload = () => this.logoPreview.set(reader.result as string);
    reader.readAsDataURL(file);
  }

  onKycFrontSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    this.selectedKycFront = input.files?.[0] ?? null;
  }

  onKycBackSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    this.selectedKycBack = input.files?.[0] ?? null;
  }

  onSubmit(): void {
    if (this.signupForm.invalid) {
      this.notification.show('Vérifie les champs obligatoires.', 'error');
      return;
    }
    const v = this.signupForm.getRawValue();
    if (v.password !== v.confirmPassword) {
      this.notification.show('Les mots de passe ne correspondent pas.', 'error');
      return;
    }
    // kycFront/kycBack obligatoires côté backend (@RequestPart sans required=false) — sans eux
    // la requête échoue avec un 400, mieux vaut bloquer avant l'appel réseau.
    if (!this.selectedKycFront || !this.selectedKycBack) {
      this.notification.show(
        'Les pièces d’identité du responsable (recto + verso) sont obligatoires.',
        'error',
      );
      return;
    }
    this.isLoading.set(true);

    this.authService
      .registerCompany(
        {
          firstname: v.firstname.trim(),
          lastname: v.lastname.trim(),
          login: v.login.trim(),
          email: v.email?.trim() || undefined,
          phone: v.phone.trim(),
          password: v.password,
          companyName: v.companyName.trim(),
          companyEmail: v.companyEmail?.trim() || undefined,
          companyPhone: v.companyPhone.trim(),
          businessNumber: v.businessNumber?.trim() || undefined,
        },
        this.selectedKycFront,
        this.selectedKycBack,
        this.selectedLogo,
      )
      .subscribe({
        next: () => {
          void this.router.navigateByUrl('/partenaire/dashboard');
        },
        error: (err: HttpErrorResponse) => {
          this.isLoading.set(false);
          const msg = extractApiErrorMessage(
            err,
            'Inscription impossible. Vérifie tes informations ou réessaie plus tard.',
          );
          this.notification.show(msg, 'error');
          console.error('[register-partner]', err);
        },
      });
  }
}
