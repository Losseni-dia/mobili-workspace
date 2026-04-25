import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { TripService } from '../../../core/services/trip/trip.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { VEHICLE_TYPE_COVOITURAGE_SELECT, type VehicleTypeName } from '../../../core/constants/vehicle-types';

@Component({
  selector: 'app-covoiturage-publish',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './covoiturage-publish.component.html',
  styleUrl: './covoiturage-publish.component.scss',
})
export class CovoituragePublishComponent implements OnInit, OnDestroy {
  private fb = inject(FormBuilder);
  private tripService = inject(TripService);
  private router = inject(Router);
  private notify = inject(NotificationService);
  auth = inject(AuthService);

  vehicleTypes = VEHICLE_TYPE_COVOITURAGE_SELECT;
  isLoading = signal(false);
  err = signal<string | null>(null);
  vehPhoto: File | null = null;
  /** Aperçu local (fichier choisi sur ce formulaire) */
  localPreview = signal<string | null>(null);

  /** Profil + fichier local : ce qui s’affiche dans la zone photo */
  displayPhoto = computed(() => {
    const local = this.localPreview();
    if (local) {
      return local;
    }
    return this.toAbsolute(this.auth.currentUser()?.covoiturageVehiclePhotoUrl);
  });

  isUsingNewFile = computed(() => this.localPreview() != null);
  hasVehicleHintFromProfile = computed(
    () => !this.localPreview() && !!this.auth.currentUser()?.covoiturageVehiclePhotoUrl,
  );

  form = this.fb.group({
    departureCity: ['', Validators.required],
    arrivalCity: ['', Validators.required],
    boardingPoint: ['', Validators.required],
    vehiculePlateNumber: [''],
    vehicleType: ['VAN' as VehicleTypeName, Validators.required],
    departureDateTime: ['', Validators.required],
    price: [null as number | null, [Validators.required, Validators.min(0)]],
    totalSeats: [3, [Validators.required, Validators.min(1)]],
    moreInfo: [''],
  });

  private toAbsolute(path: string | null | undefined): string | null {
    if (!path) {
      return null;
    }
    if (path.startsWith('http')) {
      return path;
    }
    return `${this.auth.IMAGE_BASE_URL}${path}`;
  }

  ngOnInit(): void {
    this.auth.fetchUserProfile().subscribe({
      next: (u) => {
        const plate = u.covoiturageVehiclePlate?.trim();
        if (plate && !this.form.get('vehiculePlateNumber')?.value) {
          this.form.patchValue({ vehiculePlateNumber: plate });
        }
      },
      error: () => {},
    });
  }

  ngOnDestroy(): void {
    const p = this.localPreview();
    if (p) {
      URL.revokeObjectURL(p);
    }
  }

  onFile(ev: Event) {
    const input = ev.target as HTMLInputElement;
    const prev = this.localPreview();
    if (prev) {
      URL.revokeObjectURL(prev);
    }
    const f = input.files?.[0];
    this.vehPhoto = f ?? null;
    this.localPreview.set(f ? URL.createObjectURL(f) : null);
  }

  clearNewFile(input: HTMLInputElement) {
    const p = this.localPreview();
    if (p) {
      URL.revokeObjectURL(p);
    }
    this.localPreview.set(null);
    this.vehPhoto = null;
    input.value = '';
  }

  submit() {
    this.err.set(null);
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    const v = this.form.getRawValue();
    const body = {
      departureCity: v.departureCity!.trim(),
      arrivalCity: v.arrivalCity!.trim(),
      boardingPoint: v.boardingPoint!.trim(),
      vehiculePlateNumber: v.vehiculePlateNumber?.trim() || undefined,
      vehicleType: v.vehicleType!,
      departureDateTime: v.departureDateTime!,
      price: Number(v.price),
      totalSeats: Number(v.totalSeats),
      moreInfo: v.moreInfo?.trim() || undefined,
    };
    this.isLoading.set(true);
    const fd = new FormData();
    fd.append(
      'trip',
      new Blob([JSON.stringify(body)], { type: 'application/json' }),
      'trip.json',
    );
    if (this.vehPhoto) {
      fd.append('vehicleImage', this.vehPhoto);
    }
    this.tripService.createCovoiturageSoloTrip(fd).subscribe({
      next: (t) => {
        this.isLoading.set(false);
        this.notify.show(`Voyage #${t.id} publié.`, 'success');
        void this.router.navigate(['/covoiturage/accueil'], { queryParams: { created: t.id } });
      },
      error: (e) => {
        this.isLoading.set(false);
        const msg =
          e?.error?.message ||
          (typeof e?.error === 'string' ? e.error : null) ||
          'Impossible de publier le voyage.';
        this.err.set(String(msg));
      },
    });
  }
}
