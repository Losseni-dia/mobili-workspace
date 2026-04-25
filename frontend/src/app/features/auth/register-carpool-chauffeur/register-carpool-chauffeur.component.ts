import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';

@Component({
  selector: 'app-register-carpool-chauffeur',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './register-carpool-chauffeur.component.html',
  styleUrls: ['./register-carpool-chauffeur.component.scss'],
})
export class RegisterCarpoolChauffeurComponent {
  private fb = inject(FormBuilder);
  private authService = inject(AuthService);
  private router = inject(Router);

  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  idFront: File | null = null;
  idBack: File | null = null;
  driverPhoto: File | null = null;
  vehiclePhoto: File | null = null;

  form = this.fb.group({
    firstname: ['', [Validators.required, Validators.maxLength(80)]],
    lastname: ['', [Validators.required, Validators.maxLength(80)]],
    login: ['', [Validators.required, Validators.maxLength(64)]],
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(6)]],
    confirmPassword: ['', [Validators.required]],
    idValidUntil: ['', [Validators.required]],
    vehicleBrand: ['', [Validators.required, Validators.maxLength(80)]],
    vehiclePlate: ['', [Validators.required, Validators.maxLength(32)]],
    vehicleColor: ['', [Validators.required, Validators.maxLength(40)]],
    greyCardNumber: ['', [Validators.required, Validators.maxLength(64)]],
  });

  onIdFront(ev: Event) {
    const f = (ev.target as HTMLInputElement).files?.[0];
    this.idFront = f ?? null;
  }

  onIdBack(ev: Event) {
    const f = (ev.target as HTMLInputElement).files?.[0];
    this.idBack = f ?? null;
  }

  onDriverPhoto(ev: Event) {
    const f = (ev.target as HTMLInputElement).files?.[0];
    this.driverPhoto = f ?? null;
  }

  onVehiclePhoto(ev: Event) {
    const f = (ev.target as HTMLInputElement).files?.[0];
    this.vehiclePhoto = f ?? null;
  }

  submit() {
    this.errorMessage.set(null);
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const v = this.form.getRawValue();
    if (v.password !== v.confirmPassword) {
      this.errorMessage.set('Les mots de passe ne correspondent pas.');
      return;
    }
    if (!this.idFront || !this.idBack) {
      this.errorMessage.set('Le recto et le verso de la pièce d’identité sont obligatoires.');
      return;
    }
    if (!this.driverPhoto) {
      this.errorMessage.set('La photo du conducteur (portrait) est obligatoire.');
      return;
    }
    if (!this.vehiclePhoto) {
      this.errorMessage.set('La photo du véhicule est obligatoire.');
      return;
    }
    const idF = this.idFront;
    const idB = this.idBack;
    const driverP = this.driverPhoto;
    const vehP = this.vehiclePhoto;
    this.isLoading.set(true);
    this.authService
      .registerCarpoolChauffeur(
        {
          firstname: v.firstname!.trim(),
          lastname: v.lastname!.trim(),
          login: v.login!.trim(),
          email: v.email!.trim(),
          password: v.password!,
          idValidUntil: v.idValidUntil!,
          vehicleBrand: v.vehicleBrand!.trim(),
          vehiclePlate: v.vehiclePlate!.trim(),
          vehicleColor: v.vehicleColor!.trim(),
          greyCardNumber: v.greyCardNumber!.trim(),
        },
        idF,
        idB,
        driverP,
        vehP,
      )
      .subscribe({
        next: () => {
          this.isLoading.set(false);
          void this.router.navigate(['/auth/login'], {
            queryParams: { registered: 'carpool' },
          });
        },
        error: (err) => {
          this.isLoading.set(false);
          const msg =
            err?.error?.message ||
            err?.error?.error ||
            (typeof err?.error === 'string' ? err.error : null) ||
            'Inscription impossible. Vérifiez les champs et réessayez.';
          this.errorMessage.set(String(msg));
        },
      });
  }
}
