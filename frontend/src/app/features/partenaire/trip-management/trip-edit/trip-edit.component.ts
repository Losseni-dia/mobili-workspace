import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterModule } from '@angular/router';
import { startWith } from 'rxjs';

import { buildTripCityLabels, lastStopIndexFromLabels } from '../../../../core/utils/trip-city-labels.util';
import { ConfigurationService } from '../../../../configurations/services/configuration.service';
import { AuthService } from '../../../../core/services/auth/auth.service';
import { PartenaireService, PartnerChauffeurItem } from '../../../../core/services/partners/partenaire.service';
import { TripLegFarePayload, TripService } from '../../../../core/services/trip/trip.service';
import { NotificationService } from '../../../../core/services/notification/notification.service';
import { VEHICLE_TYPE_ENUM_OPTIONS, type VehicleTypeName } from '../../../../core/constants/vehicle-types';

@Component({
  selector: 'app-trip-edit',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule],
  templateUrl: './trip-edit.component.html',
  styleUrls: ['./trip-edit.component.scss'],
})
export class TripEditComponent implements OnInit {
  private fb = inject(FormBuilder);
  private tripService = inject(TripService);
  private partenaireService = inject(PartenaireService);
  private authService = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private notification = inject(NotificationService);
  private configuration = inject(ConfigurationService);

  tripId!: number;
  selectedFile: File | null = null;
  imagePreview = signal<string | null>(null);
  isLoading = signal(false);

  cityLabelsPreview = signal<string[]>([]);
  legPrices = signal<number[]>([]);
  chauffeurs = signal<PartnerChauffeurItem[]>([]);
  /** Gare rattachée au trajet (filtrer la liste des conducteurs côté partenaire). */
  tripStationId = signal<number | null>(null);
  /** Affectation conducteur : masqué pour covoiturage particulier. */
  showChauffeurPicker = signal(true);

  eligibleChauffeurs = computed(() => {
    const list = this.chauffeurs();
    const u = this.authService.currentUser();
    if (this.authService.hasRole('GARE') && u?.stationId) {
      return list.filter((c) => c.affiliationStationId === u.stationId);
    }
    const sid = this.tripStationId();
    if (sid != null) {
      return list.filter((c) => c.affiliationStationId === sid);
    }
    return list;
  });

  legRows = computed(() => {
    const labs = this.cityLabelsPreview();
    const prices = this.legPrices();
    const rows: { index: number; fromLabel: string; toLabel: string; price: number }[] = [];
    for (let i = 0; i < labs.length - 1; i++) {
      rows.push({
        index: i,
        fromLabel: labs[i] || '—',
        toLabel: labs[i + 1] || '—',
        price: prices[i] ?? 0,
      });
    }
    return rows;
  });

  legsTotal = computed(() => this.legPrices().reduce((a, b) => a + b, 0));

  needsOriginDestinationPrice = computed(() => this.legRows().length > 1);
  firstCityLabel = computed(() => this.cityLabelsPreview()[0]?.trim() || 'Départ');
  lastCityLabel = computed(
    () => this.cityLabelsPreview()[this.cityLabelsPreview().length - 1]?.trim() || 'Arrivée',
  );

  /** Aligné sur le backend {@code VehicleType} (option value = nom d’enum). */
  vehicleTypeOptions = VEHICLE_TYPE_ENUM_OPTIONS;

  tripForm = this.fb.group({
    departureCity: ['', Validators.required],
    arrivalCity: ['', Validators.required],
    departureDateTime: ['', Validators.required],
    vehiculePlateNumber: ['', Validators.required],
    boardingPoint: ['', Validators.required],
    stops: [''],
    price: [null as number | null, [Validators.min(0)]],
    originDestinationPrice: [null as number | null, [Validators.min(0)]],
    availableSeats: [null as number | null, [Validators.required, Validators.min(1)]],
    vehicleType: ['', Validators.required],
    transportType: ['PUBLIC' as 'PUBLIC' | 'COVOITURAGE', Validators.required],
    assignedChauffeurId: [null as number | null],
    includedCabinBagsPerPassenger: [1, [Validators.min(0)]],
    includedHoldBagsPerPassenger: [1, [Validators.min(0)]],
    maxExtraHoldBagsPerPassenger: [1, [Validators.min(0)]],
    extraHoldBagPrice: [0, [Validators.min(0)]],
  });

  ngOnInit() {
    this.tripId = Number(this.route.snapshot.paramMap.get('id'));

    this.partenaireService.listChauffeurs().subscribe({
      next: (list) => this.chauffeurs.set(list),
      error: () => this.chauffeurs.set([]),
    });

    this.syncLegPrices();
    this.tripForm.valueChanges.pipe(startWith(this.tripForm.value)).subscribe(() => this.syncLegPrices());

    this.loadTripData();

    this.tripForm.get('vehicleType')?.valueChanges.subscribe((type) => {
      const row = VEHICLE_TYPE_ENUM_OPTIONS.find((o) => o.name === type);
      if (row) {
        this.tripForm.patchValue({ availableSeats: row.defaultSeats });
      }
    });
  }

  /** API peut renvoyer le nom d’enum ou l’ancien libellé affiché. */
  private vehicleTypeFromApi(raw: string | undefined | null): VehicleTypeName {
    if (!raw) {
      return 'MASSA_NORMAL';
    }
    if (VEHICLE_TYPE_ENUM_OPTIONS.some((o) => o.name === raw)) {
      return raw as VehicleTypeName;
    }
    const byLabel = VEHICLE_TYPE_ENUM_OPTIONS.find((o) => o.label === raw);
    return (byLabel?.name ?? 'MASSA_NORMAL') as VehicleTypeName;
  }

  onLegPriceInput(legIndex: number, ev: Event) {
    const el = ev.target as HTMLInputElement;
    const v = Number(el.value);
    const next = [...this.legPrices()];
    next[legIndex] = Number.isNaN(v) || v < 0 ? 0 : v;
    this.legPrices.set(next);
  }

  loadTripData() {
    this.tripService.getTripById(this.tripId).subscribe({
      next: (trip: {
        departureCity: string;
        arrivalCity: string;
        departureDateTime?: string;
        vehiculePlateNumber: string;
        boardingPoint: string;
        moreInfo?: string;
        price: number;
        originDestinationPrice?: number | null;
        availableSeats: number;
        vehicleType: string;
        vehicleImageUrl?: string;
        legFares?: { fromStopIndex: number; toStopIndex: number; price: number }[];
        transportType?: string;
        stationId?: number | null;
        covoiturageOrganizerId?: number | null;
        assignedChauffeurId?: number | null;
        includedCabinBagsPerPassenger?: number;
        includedHoldBagsPerPassenger?: number;
        maxExtraHoldBagsPerPassenger?: number;
        extraHoldBagPrice?: number;
      }) => {
        const covoit = trip.covoiturageOrganizerId != null && trip.covoiturageOrganizerId > 0;
        this.showChauffeurPicker.set(!covoit);
        this.tripStationId.set(trip.stationId != null && trip.stationId > 0 ? trip.stationId : null);

        if (trip.legFares && trip.legFares.length > 0) {
          const sorted = [...trip.legFares].sort((a, b) => a.fromStopIndex - b.fromStopIndex);
          this.legPrices.set(sorted.map((f) => f.price));
        } else {
          this.legPrices.set([]);
        }

        this.tripForm.patchValue(
          {
            departureCity: trip.departureCity,
            arrivalCity: trip.arrivalCity,
            departureDateTime: trip.departureDateTime?.slice(0, 16),
            vehiculePlateNumber: trip.vehiculePlateNumber,
            boardingPoint: trip.boardingPoint,
            stops: trip.moreInfo,
            price: trip.price,
            originDestinationPrice:
              trip.originDestinationPrice != null
                ? trip.originDestinationPrice
                : trip.legFares && trip.legFares.length > 1
                  ? trip.price
                  : null,
            availableSeats: trip.availableSeats,
            vehicleType: this.vehicleTypeFromApi(trip.vehicleType),
            transportType:
              trip.transportType === 'COVOITURAGE' || trip.transportType === 'PUBLIC'
                ? trip.transportType
                : 'PUBLIC',
            includedCabinBagsPerPassenger: trip.includedCabinBagsPerPassenger ?? 1,
            includedHoldBagsPerPassenger: trip.includedHoldBagsPerPassenger ?? 1,
            maxExtraHoldBagsPerPassenger: trip.maxExtraHoldBagsPerPassenger ?? 1,
            extraHoldBagPrice: trip.extraHoldBagPrice ?? 0,
          },
          { emitEvent: false },
        );

        if (trip.vehicleImageUrl) {
          const url = this.configuration.resolveUploadMediaUrl(trip.vehicleImageUrl);
          if (url) {
            this.imagePreview.set(url);
          }
        }

        this.syncLegPrices();
      },
    });
  }

  private syncLegPrices() {
    const v = this.tripForm.getRawValue();
    const labels = buildTripCityLabels(
      v.departureCity ?? '',
      v.arrivalCity ?? '',
      v.stops ?? '',
    );
    this.cityLabelsPreview.set(labels);

    const last = lastStopIndexFromLabels(labels);

    if (last <= 0) {
      this.legPrices.set([]);
    } else if (this.legPrices().length !== last) {
      const prev = this.legPrices();
      this.legPrices.set(
        Array.from({ length: last }, (_, i) => (i < prev.length ? prev[i]! : 0)),
      );
    }
  }

  onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (file) {
      this.selectedFile = file;
      const reader = new FileReader();
      reader.onload = () => this.imagePreview.set(reader.result as string);
      reader.readAsDataURL(file);
    }
  }

  onSubmit() {
    if (this.tripForm.invalid || this.isLoading()) return;

    const labels = buildTripCityLabels(
      this.tripForm.value.departureCity ?? '',
      this.tripForm.value.arrivalCity ?? '',
      this.tripForm.value.stops ?? '',
    );
    const last = lastStopIndexFromLabels(labels);
    const legs = this.legPrices();
    if (last > 0) {
      if (legs.length !== last || legs.some((p) => p == null || p <= 0 || Number.isNaN(p))) {
        this.notification.show('Indiquez un prix strictement positif pour chaque tronçon.', 'error');
        return;
      }
    } else {
      const p = Number(this.tripForm.value.price);
      if (p == null || p <= 0 || Number.isNaN(p)) {
        this.notification.show('Indiquez un prix valide pour le trajet.', 'error');
        return;
      }
    }

    this.isLoading.set(true);

    const formData = new FormData();
    const formValue = this.tripForm.value;
    const currentUser = this.authService.currentUser();

    const dateInput = new Date(formValue.departureDateTime!);
    const offset = dateInput.getTimezoneOffset() * 60000;
    const localISOTime = new Date(dateInput.getTime() - offset).toISOString().slice(0, 19);

    const sumLegs =
      last > 0 && legs.length === last ? legs.reduce((a, b) => a + b, 0) : Number(formValue.price ?? 0);
    let mainTripPrice: number;
    if (last > 1) {
      const od = Number(formValue.originDestinationPrice);
      if (!Number.isFinite(od) || od <= 0) {
        this.notification.show('Indiquez le prix du trajet complet (départ → arrivée final), positif.', 'error');
        this.isLoading.set(false);
        return;
      }
      mainTripPrice = od;
    } else {
      mainTripPrice = last > 0 ? sumLegs : Number(formValue.price ?? 0);
    }
    if (!Number.isFinite(mainTripPrice) || mainTripPrice < 0) {
      this.notification.show('Prix du trajet invalide.', 'error');
      this.isLoading.set(false);
      return;
    }

    const partnerId = currentUser?.partnerId ?? currentUser?.id;
    if (partnerId == null || !Number.isFinite(Number(partnerId))) {
      this.notification.show('Compte partenaire introuvable (partnerId). Reconnecte-toi.', 'error');
      this.isLoading.set(false);
      return;
    }

    const tripPayload: Record<string, unknown> = {
      id: this.tripId,
      partnerId: Number(partnerId),
      departureCity: formValue.departureCity,
      arrivalCity: formValue.arrivalCity,
      boardingPoint: formValue.boardingPoint,
      vehiculePlateNumber: formValue.vehiculePlateNumber,
      vehicleType: formValue.vehicleType,
      departureDateTime: localISOTime,
      price: mainTripPrice,
      totalSeats: formValue.availableSeats,
      availableSeats: formValue.availableSeats,
      moreInfo: formValue.stops,
    };
    if (last > 1) {
      tripPayload['originDestinationPrice'] = mainTripPrice;
    }

    if (last > 0 && legs.length === last) {
      tripPayload['legFares'] = legs.map((p, i) => ({
        fromStopIndex: i,
        toStopIndex: i + 1,
        price: p,
      }));
    } else {
      tripPayload['legFares'] = [];
    }
    tripPayload['transportType'] = formValue.transportType ?? 'PUBLIC';

    if (this.showChauffeurPicker()) {
      const aid = formValue.assignedChauffeurId;
      tripPayload['assignedChauffeurId'] = aid != null && aid > 0 ? aid : 0;
    }

    tripPayload['includedCabinBagsPerPassenger'] = Number(formValue.includedCabinBagsPerPassenger ?? 1);
    tripPayload['includedHoldBagsPerPassenger'] = Number(formValue.includedHoldBagsPerPassenger ?? 1);
    tripPayload['maxExtraHoldBagsPerPassenger'] = Number(formValue.maxExtraHoldBagsPerPassenger ?? 1);
    tripPayload['extraHoldBagPrice'] = Number(formValue.extraHoldBagPrice ?? 0);

    formData.append('trip', new Blob([JSON.stringify(tripPayload)], { type: 'application/json' }));
    if (this.selectedFile) {
      formData.append('vehicleImage', this.selectedFile);
    }

    this.tripService.updateTrip(this.tripId, formData).subscribe({
      next: () => this.router.navigate(['/partenaire/trips']),
      error: (err: unknown) => {
        this.isLoading.set(false);
        const e = err as { error?: { message?: string; title?: string; errors?: { defaultMessage?: string }[] } };
        const parts: string[] = [];
        if (typeof e?.error?.message === 'string') parts.push(e.error.message);
        if (typeof e?.error?.title === 'string') parts.push(e.error.title);
        if (Array.isArray(e?.error?.errors)) {
          for (const x of e.error.errors) {
            if (typeof x?.defaultMessage === 'string') parts.push(x.defaultMessage);
          }
        }
        const msg = parts.filter(Boolean).join(' ') || 'Mise à jour impossible. Vérifie les champs et réessaie.';
        this.notification.show(msg, 'error');
        console.error('Erreur Update :', err);
      },
    });
  }
}
