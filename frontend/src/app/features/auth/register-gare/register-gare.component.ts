import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import {
  AuthService,
  GarePreviewResponse,
} from '../../../core/services/auth/auth.service';

@Component({
  selector: 'app-register-gare',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './register-gare.component.html',
  styleUrls: ['./register-gare.component.scss'],
})
export class RegisterGareComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);

  step = signal<1 | 2>(1);
  preview = signal<GarePreviewResponse | null>(null);
  isLoadingPreview = signal(false);
  isSubmitting = signal(false);
  errorMessage = signal<string | null>(null);
  /** Inscription réussie mais compte inactif jusqu’à validation du partenaire. */
  awaitingApprovalMessage = signal<string | null>(null);
  showPassword = signal(false);

  codeForm = this.fb.group({
    partnerCode: ['', [Validators.required, Validators.minLength(4)]],
  });

  /** Rattachement : gare existante ou nouvelle (affiché à l’étape 2). */
  stationMode = signal<'existing' | 'new'>('existing');

  registerForm = this.fb.group({
    stationId: [null as number | null],
    newStationName: [''],
    newStationCity: [''],
    login: ['', [Validators.required, Validators.minLength(3)]],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]],
    firstname: ['', [Validators.required]],
    lastname: ['', [Validators.required]],
  });

  runPreview() {
    const code = this.codeForm.get('partnerCode')?.value?.trim();
    if (!code) return;
    this.errorMessage.set(null);
    this.isLoadingPreview.set(true);
    this.authService.previewGareRegistration(code).subscribe({
      next: (data) => {
        this.preview.set(data);
        const hasStations = data.stations?.length > 0;
        this.stationMode.set(hasStations ? 'existing' : 'new');
        if (hasStations) {
          this.registerForm.patchValue({ stationId: data.stations[0].id });
        } else {
          this.registerForm.patchValue({ stationId: null });
        }
        this.step.set(2);
        this.isLoadingPreview.set(false);
      },
      error: () => {
        this.isLoadingPreview.set(false);
        this.errorMessage.set('Code inconnu ou compagnie indisponible. Vérifiez le code fourni par votre partenaire.');
      },
    });
  }

  backToCode() {
    this.step.set(1);
    this.preview.set(null);
    this.errorMessage.set(null);
  }

  selectStationMode(mode: 'existing' | 'new') {
    this.stationMode.set(mode);
    if (mode === 'new') {
      this.registerForm.patchValue({ stationId: null });
    } else {
      const p = this.preview();
      if (p?.stations?.length) {
        this.registerForm.patchValue({ stationId: p.stations[0].id });
      }
    }
  }

  onStationIdChange(id: string) {
    this.registerForm.patchValue({ stationId: id ? Number(id) : null });
  }

  onSubmitGare() {
    if (this.registerForm.invalid) {
      this.registerForm.markAllAsTouched();
      this.errorMessage.set(this.formInvalidReason());
      return;
    }
    const p = this.preview();
    if (!p) return;

    const v = this.registerForm.getRawValue();
    const code = this.codeForm.get('partnerCode')?.value?.trim() ?? '';
    const hasStations = p.stations.length > 0;
    const mode = hasStations ? this.stationMode() : 'new';

    if (hasStations && mode === 'existing' && (v.stationId == null || isNaN(+v.stationId))) {
      this.errorMessage.set('Sélectionnez une gare.');
      return;
    }
    if (mode === 'new') {
      const n = v.newStationName?.trim() ?? '';
      const c = v.newStationCity?.trim() ?? '';
      if (n.length < 2 || c.length < 2) {
        this.errorMessage.set('Indiquez le nom et la ville de la gare.');
        return;
      }
    }

    this.errorMessage.set(null);
    this.isSubmitting.set(true);

    const body = {
      partnerCode: code.toUpperCase(),
      stationId: mode === 'existing' && v.stationId != null ? v.stationId : undefined,
      newStationName: mode === 'new' ? v.newStationName?.trim() : undefined,
      newStationCity: mode === 'new' ? v.newStationCity?.trim() : undefined,
      login: v.login!.trim(),
      email: v.email!.trim(),
      password: v.password!,
      firstname: v.firstname!.trim(),
      lastname: v.lastname!.trim(),
    };

    this.authService.registerGare(body).subscribe({
      next: (outcome) => {
        this.isSubmitting.set(false);
        if (outcome.status === 'awaiting_approval') {
          this.awaitingApprovalMessage.set(
            `Compte créé pour « ${outcome.login} ». Il sera activé dès que le dirigeant aura approuvé la gare dans l’espace partenaire.`,
          );
          return;
        }
        this.router.navigateByUrl('/gare/accueil');
      },
      error: (err) => {
        this.isSubmitting.set(false);
        const msg = err?.error?.message;
        this.errorMessage.set(
          typeof msg === 'string' ? msg : "Impossible de finaliser l'inscription. Vérifiez les champs et réessayez.",
        );
      },
    });
  }

  togglePassword() {
    this.showPassword.update((x) => !x);
  }

  /** Message lisible quand l’utilisateur clique alors que le formulaire est invalide (ex. mot de passe trop court). */
  private formInvalidReason(): string {
    const c = this.registerForm.controls;
    const pwd = c['password'];
    if (pwd?.errors?.['required'] || pwd?.errors?.['minlength']) {
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    }
    if (c['email']?.errors?.['required']) {
      return 'L’adresse e-mail est obligatoire.';
    }
    if (c['email']?.errors?.['email']) {
      return 'Indiquez une adresse e-mail valide.';
    }
    if (c['login']?.errors?.['required'] || c['login']?.errors?.['minlength']) {
      return 'L’identifiant (login) doit comporter au moins 3 caractères.';
    }
    if (c['firstname']?.errors?.['required'] || c['lastname']?.errors?.['required']) {
      return 'Renseignez le prénom et le nom.';
    }
    return 'Vérifiez que tous les champs obligatoires sont correctement remplis.';
  }
}
