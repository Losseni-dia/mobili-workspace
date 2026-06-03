import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { MobiliSecureUploadImgComponent } from '../../../shared/upload/mobili-secure-upload-img.component';

@Component({
  selector: 'app-covoiturage-profil',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink, MobiliSecureUploadImgComponent],
  templateUrl: './covoiturage-profil.component.html',
  styleUrl: './covoiturage-profil.component.scss',
})
export class CovoiturageProfilComponent implements OnInit, OnDestroy {
  private readonly fb = inject(FormBuilder);
  readonly auth = inject(AuthService);
  private readonly notify = inject(NotificationService);

  u = computed(() => this.auth.currentUser());
  isLoading = signal(false);
  err = signal<string | null>(null);

  driverPhotoFile: File | null = null;
  vehiclePhotoFile: File | null = null;
  driverPreview = signal<string | null>(null);
  vehiclePreview = signal<string | null>(null);

  form = this.fb.group({
    vehicleBrand: [''],
    vehiclePlate: [''],
    vehicleColor: [''],
    greyCardNumber: [''],
  });

  ngOnInit(): void {
    this.auth.fetchUserProfile().subscribe({
      next: (u) => {
        this.form.patchValue({
          vehicleBrand: u.covoiturageVehicleBrand ?? '',
          vehiclePlate: u.covoiturageVehiclePlate ?? '',
          vehicleColor: u.covoiturageVehicleColor ?? '',
          greyCardNumber: u.covoiturageGreyCardNumber ?? '',
        });
      },
      error: () => {},
    });
  }

  ngOnDestroy(): void {
    const dp = this.driverPreview();
    if (dp) URL.revokeObjectURL(dp);
    const vp = this.vehiclePreview();
    if (vp) URL.revokeObjectURL(vp);
  }

  kycStatusLabel(s: string | null | undefined): string {
    const m: Record<string, string> = {
      NONE: 'Non transmis',
      PENDING: 'En attente de validation',
      APPROVED: 'Validé ✓',
      REJECTED: 'Refusé',
      EXPIRED: 'CNI expirée',
    };
    return s ? (m[s] ?? s) : '—';
  }

  kycStatusClass(s: string | null | undefined): string {
    const m: Record<string, string> = {
      APPROVED: 'tag--ok',
      PENDING: 'tag--warn',
      REJECTED: 'tag--err',
      EXPIRED: 'tag--err',
    };
    return s ? (m[s] ?? '') : '';
  }

  onDriverPhoto(ev: Event) {
    const f = (ev.target as HTMLInputElement).files?.[0];
    const prev = this.driverPreview();
    if (prev) URL.revokeObjectURL(prev);
    this.driverPhotoFile = f ?? null;
    this.driverPreview.set(f ? URL.createObjectURL(f) : null);
  }

  clearDriverPhoto(input: HTMLInputElement) {
    const p = this.driverPreview();
    if (p) URL.revokeObjectURL(p);
    this.driverPreview.set(null);
    this.driverPhotoFile = null;
    input.value = '';
  }

  onVehiclePhoto(ev: Event) {
    const f = (ev.target as HTMLInputElement).files?.[0];
    const prev = this.vehiclePreview();
    if (prev) URL.revokeObjectURL(prev);
    this.vehiclePhotoFile = f ?? null;
    this.vehiclePreview.set(f ? URL.createObjectURL(f) : null);
  }

  clearVehiclePhoto(input: HTMLInputElement) {
    const p = this.vehiclePreview();
    if (p) URL.revokeObjectURL(p);
    this.vehiclePreview.set(null);
    this.vehiclePhotoFile = null;
    input.value = '';
  }

  submit() {
    this.err.set(null);
    const v = this.form.getRawValue();
    const body = {
      vehicleBrand: v.vehicleBrand?.trim() ?? '',
      vehiclePlate: v.vehiclePlate?.trim() ?? '',
      vehicleColor: v.vehicleColor?.trim() ?? '',
      greyCardNumber: v.greyCardNumber?.trim() ?? '',
    };
    const fd = new FormData();
    fd.append('profile', new Blob([JSON.stringify(body)], { type: 'application/json' }), 'profile.json');
    if (this.driverPhotoFile) fd.append('driverPhoto', this.driverPhotoFile);
    if (this.vehiclePhotoFile) fd.append('vehiclePhoto', this.vehiclePhotoFile);

    this.isLoading.set(true);
    this.auth.updateCovoiturageProfile(fd).subscribe({
      next: () => {
        this.isLoading.set(false);
        this.notify.show('Profil mis à jour.', 'success');
        this.driverPhotoFile = null;
        this.vehiclePhotoFile = null;
        const dp = this.driverPreview();
        if (dp) URL.revokeObjectURL(dp);
        const vp = this.vehiclePreview();
        if (vp) URL.revokeObjectURL(vp);
        this.driverPreview.set(null);
        this.vehiclePreview.set(null);
      },
      error: (e) => {
        this.isLoading.set(false);
        this.err.set(e?.error?.message || 'Impossible de mettre à jour le profil.');
      },
    });
  }
}
