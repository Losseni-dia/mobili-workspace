import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';

import { NotificationService } from '../../../core/services/notification/notification.service';
import { AuthService } from '../../../core/services/auth/auth.service';

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

  signupForm = this.fb.nonNullable.group({
    firstname: ['', [Validators.required]],
    lastname: ['', [Validators.required]],
    login: ['', [Validators.required, Validators.minLength(3)]],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]],
    confirmPassword: ['', [Validators.required]],
    companyName: ['', [Validators.required]],
    companyEmail: ['', [Validators.required, Validators.email]],
    companyPhone: ['', [Validators.required]],
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
    this.isLoading.set(true);

    this.authService
      .registerCompany(
        {
          firstname: v.firstname.trim(),
          lastname: v.lastname.trim(),
          login: v.login.trim(),
          email: v.email.trim(),
          password: v.password,
          companyName: v.companyName.trim(),
          companyEmail: v.companyEmail.trim(),
          companyPhone: v.companyPhone.trim(),
          businessNumber: v.businessNumber?.trim() || undefined,
        },
        this.selectedLogo,
      )
      .subscribe({
        next: () => {
          void this.router.navigateByUrl('/partenaire/dashboard');
        },
        error: (err: unknown) => {
          this.isLoading.set(false);
          const msg =
            err &&
            typeof err === 'object' &&
            'error' in err &&
            err.error &&
            typeof err.error === 'object' &&
            typeof (err.error as { message?: unknown }).message === 'string'
              ? (err.error as { message: string }).message
              : 'Inscription impossible. Vérifie tes informations ou réessaie plus tard.';
          this.notification.show(msg, 'error');
          console.error('[register-partner]', err);
        },
      });
  }
}
