import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TripService } from '../../../core/services/trip/trip.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { VEHICLE_TYPE_COVOITURAGE_SELECT, type VehicleTypeName } from '../../../core/constants/vehicle-types';
import { MobiliSecureUploadImgComponent } from '../../../shared/upload/mobili-secure-upload-img.component';

@Component({
  selector: 'app-covoiturage-edit',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink, MobiliSecureUploadImgComponent],
  templateUrl: './covoiturage-edit.component.html',
  styleUrl: './covoiturage-edit.component.scss',
})
export class CovoiturageEditComponent implements OnInit, OnDestroy {
  private readonly fb = inject(FormBuilder);
  private readonly tripService = inject(TripService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly notify = inject(NotificationService);
  auth = inject(AuthService);

  vehicleTypes = VEHICLE_TYPE_COVOITURAGE_SELECT;
  isLoading = signal(false);
  isLoadingTrip = signal(true);
  err = signal<string | null>(null);
  tripId = signal<number | null>(null);
  vehPhoto: File | null = null;
  localPreview = signal<string | null>(null);
  /** URL relative de la photo déjà enregistrée pour ce trajet */
  existingVehicleUrl = signal<string | null>(null);

  isUsingNewFile = computed(() => this.localPreview() != null);

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

  ngOnInit(): void {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    if (!id || isNaN(id)) {
      void this.router.navigate(['/covoiturage/accueil']);
      return;
    }
    this.tripId.set(id);
    this.tripService.getTripById(id).subscribe({
      next: (t) => {
        const dt = t.departureDateTime
          ? String(t.departureDateTime).substring(0, 16)
          : '';
        this.form.patchValue({
          departureCity: t.departureCity ?? '',
          arrivalCity: t.arrivalCity ?? '',
          boardingPoint: t.boardingPoint ?? '',
          vehiculePlateNumber: t.vehiculePlateNumber ?? '',
          vehicleType: (t.vehicleType ?? 'VAN') as VehicleTypeName,
          departureDateTime: dt,
          price: t.price ?? null,
          totalSeats: t.totalSeats ?? 1,
          moreInfo: t.moreInfo ?? '',
        });
        this.existingVehicleUrl.set(t.vehicleImageUrl ?? null);
        this.isLoadingTrip.set(false);
      },
      error: () => {
        this.notify.show('Impossible de charger le trajet.', 'error');
        void this.router.navigate(['/covoiturage/accueil']);
      },
    });
  }

  ngOnDestroy(): void {
    const p = this.localPreview();
    if (p) URL.revokeObjectURL(p);
  }

  onFile(ev: Event) {
    const input = ev.target as HTMLInputElement;
    const prev = this.localPreview();
    if (prev) URL.revokeObjectURL(prev);
    const f = input.files?.[0];
    this.vehPhoto = f ?? null;
    this.localPreview.set(f ? URL.createObjectURL(f) : null);
  }

  clearNewFile(input: HTMLInputElement) {
    const p = this.localPreview();
    if (p) URL.revokeObjectURL(p);
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
    const id = this.tripId();
    if (!id) return;

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

    const fd = new FormData();
    fd.append('trip', new Blob([JSON.stringify(body)], { type: 'application/json' }), 'trip.json');
    if (this.vehPhoto) {
      fd.append('vehicleImage', this.vehPhoto);
    }

    this.isLoading.set(true);
    this.tripService.updateCovoiturageSoloTrip(id, fd).subscribe({
      next: () => {
        this.isLoading.set(false);
        this.notify.show('Trajet mis à jour.', 'success');
        void this.router.navigate(['/covoiturage/accueil']);
      },
      error: (e) => {
        this.isLoading.set(false);
        const msg =
          e?.error?.message ||
          (typeof e?.error === 'string' ? e.error : null) ||
          'Impossible de modifier le voyage.';
        this.err.set(String(msg));
      },
    });
  }
}
