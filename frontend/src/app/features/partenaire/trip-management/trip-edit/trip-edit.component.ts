import { Component, computed, DestroyRef, ElementRef, inject, OnInit, signal, ViewChild } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterModule } from '@angular/router';
import { BehaviorSubject, Subject, combineLatest, of, startWith } from 'rxjs';
import { debounceTime, distinctUntilChanged, map, switchMap } from 'rxjs/operators';

import { buildTripCityLabels, lastStopIndexFromLabels } from '../../../../core/utils/trip-city-labels.util';
import { ConfigurationService } from '../../../../configurations/services/configuration.service';
import { AuthService } from '../../../../core/services/auth/auth.service';
import { PartenaireService, PartnerChauffeurItem } from '../../../../core/services/partners/partenaire.service';
import { CityOption, TripLegFarePayload, TripService } from '../../../../core/services/trip/trip.service';
import { NotificationService } from '../../../../core/services/notification/notification.service';
import { VEHICLE_TYPE_ENUM_OPTIONS, type VehicleTypeName } from '../../../../core/constants/vehicle-types';
import { extractApiErrorMessage } from '../../../../core/utils/api-error.util';

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
  private destroyRef = inject(DestroyRef);

  /** Ce composant est chargé sous /partenaire/edit-trip/:id ET /gare/edit-trip/:id
   *  (business.routes.ts) : toute navigation interne doit rester dans le bon shell, sinon
   *  partnerRoleGuard (rôle PARTNER strict) éjecte un compte gare vers '/' (effet
   *  "déconnexion" sans appel réseau). */
  basePath = computed(() => (this.authService.hasRole('GARE') ? '/gare' : '/partenaire'));

  tripId!: number;
  selectedFile: File | null = null;
  imagePreview = signal<string | null>(null);
  isLoading = signal(false);
  isPublishing = signal(false);
  /** Sécurité "Enregistrer" / "Publier" : le bouton Publier n'apparaît que tant que le
   *  trajet est encore en brouillon (DRAFT, jamais rendu visible/réservable). */
  tripStatus = signal<string | null>(null);
  /** Voir onSubmit() : tronçon(s) sans prix (ex. après ajout d'une ville étape). */
  legFaresInvalid = signal(false);
  @ViewChild('legFaresBlock') legFaresBlock?: ElementRef<HTMLElement>;

  cityLabelsPreview = signal<string[]>([]);
  /** Prix par combinaison from→to, clé "fromIndex-toIndex" — toutes les combinaisons possibles,
   *  pas seulement consécutives (voir legRows/onSubmit, même pattern qu'AddTripComponent et
   *  create_trip_page.dart), chacune optionnelle. */
  legPrices = signal<Map<string, number>>(new Map());

  /** Autocomplétion ville — voir AddTripComponent (même pattern), rattachée au pays de la
   *  société connectée. */
  myCountryId = signal<number | null>(null);
  departureSuggestions = signal<CityOption[]>([]);
  departureSelectedId = signal<number | null>(null);
  arrivalSuggestions = signal<CityOption[]>([]);
  arrivalSelectedId = signal<number | null>(null);
  activeStopIndex = signal<number | null>(null);
  stopSuggestions = signal<CityOption[]>([]);
  private stopQuery$ = new Subject<{ index: number; q: string }>();
  /** Voir StationListComponent.countryId$ (même correctif) : sans ça, la recherche exécutée
   *  avant que GET /partners/my-company ait répondu tourne avec countryId=null et ne se relance
   *  jamais toute seule (bug constaté en test : une ville existante jamais trouvée). */
  private countryId$ = new BehaviorSubject<number | null>(null);

  /** Arrêts intermédiaires — voir AddTripComponent.stopsArray (même pattern). Initialisé depuis
   *  trip.moreInfo au chargement (loadTripData), sans cityId connu (résolu par nom au prochain
   *  enregistrement, voir TripService.resolveTripCity côté backend). */
  stopsArray = this.fb.array<FormGroup>([]);
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

  /** Toutes les combinaisons from→to (pas seulement consécutives) — voir AddTripComponent.legRows
   *  (même pattern, même logique que create_trip_page.dart côté mobilipro). */
  legRows = computed(() => {
    const labs = this.cityLabelsPreview();
    const prices = this.legPrices();
    const rows: { fromIndex: number; toIndex: number; fromLabel: string; toLabel: string; price: number }[] = [];
    for (let i = 0; i < labs.length - 1; i++) {
      for (let j = i + 1; j < labs.length; j++) {
        rows.push({
          fromIndex: i,
          toIndex: j,
          fromLabel: labs[i] || '—',
          toLabel: labs[j] || '—',
          price: prices.get(`${i}-${j}`) ?? 0,
        });
      }
    }
    return rows;
  });

  /** 2+ tronçons : tarif explicite départ (ville) → arrivée (ville) distinct des tarifs par
   *  combinaison — basé sur le nombre d'arrêts, pas sur legRows() (voir AddTripComponent). */
  needsOriginDestinationPrice = computed(() => lastStopIndexFromLabels(this.cityLabelsPreview()) > 1);
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
    luggagePolicyEnabled: [false],
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
    this.partenaireService.getMyPartnerInfo().subscribe({
      next: (p) => {
        this.myCountryId.set(p.countryId ?? null);
        this.countryId$.next(p.countryId ?? null);
      },
      error: (e) => console.error('[trip-edit] Erreur chargement du pays de la société', e),
    });
    this.wireCityAutocomplete();

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

  onLegPriceInput(fromIndex: number, toIndex: number, ev: Event) {
    const el = ev.target as HTMLInputElement;
    const v = Number(el.value);
    const next = new Map(this.legPrices());
    next.set(`${fromIndex}-${toIndex}`, Number.isNaN(v) || v < 0 ? 0 : v);
    this.legPrices.set(next);
    this.legFaresInvalid.set(false);
  }

  /** Voir AddTripComponent.wireCityAutocomplete (même pattern, dupliqué à dessein — ces deux
   *  formulaires n'ont pas de classe de base commune dans ce projet). */
  private wireCityAutocomplete(): void {
    combineLatest([
      this.tripForm.get('departureCity')!.valueChanges.pipe(debounceTime(200), distinctUntilChanged()),
      this.countryId$,
    ])
      .pipe(
        switchMap(([q, countryId]) => {
          this.departureSelectedId.set(null);
          if (!countryId || !q || !q.trim()) return of([]);
          return this.tripService.getCitiesByCountry(countryId, q);
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((cities) => this.departureSuggestions.set(cities));

    combineLatest([
      this.tripForm.get('arrivalCity')!.valueChanges.pipe(debounceTime(200), distinctUntilChanged()),
      this.countryId$,
    ])
      .pipe(
        switchMap(([q, countryId]) => {
          this.arrivalSelectedId.set(null);
          if (!countryId || !q || !q.trim()) return of([]);
          return this.tripService.getCitiesByCountry(countryId, q);
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((cities) => this.arrivalSuggestions.set(cities));

    combineLatest([
      this.stopQuery$.pipe(debounceTime(200), distinctUntilChanged((a, b) => a.index === b.index && a.q === b.q)),
      this.countryId$,
    ])
      .pipe(
        switchMap(([{ index, q }, countryId]) => {
          if (!countryId || !q.trim()) return of({ index, cities: [] as CityOption[] });
          return this.tripService.getCitiesByCountry(countryId, q).pipe(map((cities) => ({ index, cities })));
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe(({ index, cities }) => {
        if (this.activeStopIndex() === index) this.stopSuggestions.set(cities);
      });

    this.stopsArray.valueChanges.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => this.syncStopsCsv());
  }

  selectDepartureCity(city: CityOption) {
    this.tripForm.patchValue({ departureCity: city.name });
    this.departureSelectedId.set(city.id);
    this.departureSuggestions.set([]);
  }

  selectArrivalCity(city: CityOption) {
    this.tripForm.patchValue({ arrivalCity: city.name });
    this.arrivalSelectedId.set(city.id);
    this.arrivalSuggestions.set([]);
  }

  addStopRow() {
    this.stopsArray.push(this.fb.group({ city: [''], cityId: [null as number | null] }));
  }

  removeStopRow(index: number) {
    this.stopsArray.removeAt(index);
    if (this.activeStopIndex() === index) {
      this.activeStopIndex.set(null);
      this.stopSuggestions.set([]);
    }
  }

  onStopCityInput(index: number, value: string) {
    this.stopsArray.at(index).patchValue({ city: value, cityId: null });
    this.activeStopIndex.set(index);
    this.stopQuery$.next({ index, q: value });
  }

  selectStopCity(index: number, city: CityOption) {
    this.stopsArray.at(index).patchValue({ city: city.name, cityId: city.id });
    this.stopSuggestions.set([]);
    this.activeStopIndex.set(null);
  }

  private syncStopsCsv() {
    const csv = this.stopsArray.controls
      .map((c) => (c.get('city')!.value || '').trim())
      .filter((name) => name !== '')
      .join(',');
    this.tripForm.get('stops')!.setValue(csv);
  }

  /** Reconstruit stopsArray depuis le CSV moreInfo chargé (loadTripData) — sans cityId connu
   *  (voir Javadoc du champ), résolu par nom au prochain enregistrement. */
  private setStopsArrayFromCsv(csv: string | null | undefined) {
    this.stopsArray.clear();
    if (!csv) return;
    for (const part of csv.split(',')) {
      const name = part.trim();
      if (name === '') continue;
      this.stopsArray.push(this.fb.group({ city: [name], cityId: [null as number | null] }), { emitEvent: false });
    }
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
        luggagePolicyEnabled?: boolean;
        status?: string;
      }) => {
        this.tripStatus.set(trip.status ?? null);
        const covoit = trip.covoiturageOrganizerId != null && trip.covoiturageOrganizerId > 0;
        this.showChauffeurPicker.set(!covoit);
        this.tripStationId.set(trip.stationId != null && trip.stationId > 0 ? trip.stationId : null);

        if (trip.legFares && trip.legFares.length > 0) {
          const map = new Map<string, number>();
          for (const f of trip.legFares) {
            map.set(`${f.fromStopIndex}-${f.toStopIndex}`, f.price);
          }
          this.legPrices.set(map);
        } else {
          this.legPrices.set(new Map());
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
            luggagePolicyEnabled: trip.luggagePolicyEnabled ?? false,
            includedCabinBagsPerPassenger: trip.includedCabinBagsPerPassenger ?? 1,
            includedHoldBagsPerPassenger: trip.includedHoldBagsPerPassenger ?? 1,
            maxExtraHoldBagsPerPassenger: trip.maxExtraHoldBagsPerPassenger ?? 1,
            extraHoldBagPrice: trip.extraHoldBagPrice ?? 0,
          },
          { emitEvent: false },
        );
        this.setStopsArrayFromCsv(trip.moreInfo);

        if (trip.vehicleImageUrl) {
          const url = this.configuration.resolveUploadMediaUrl(trip.vehicleImageUrl);
          if (url) {
            this.imagePreview.set(url);
          }
        }

        this.syncLegPrices();
      },
      // AUDIT-MOBILI.md §2.2/§2.6 : aucune gestion d'erreur ici auparavant — si l'ID de
      // trajet dans l'URL était invalide/refusé (403/404), rien ne se passait côté UI :
      // formulaire vide sans message ni redirection. Même pattern que la sauvegarde
      // (extractApiErrorMessage + NotificationService) plus redirection, puisque rester sur
      // un formulaire vide et non fonctionnel n'a aucun intérêt ici.
      error: (err) => {
        this.notification.show(
          extractApiErrorMessage(err, 'Trajet introuvable ou inaccessible.'),
          'error',
        );
        this.router.navigate([this.basePath(), 'trips']);
      },
    });
  }

  /** Ne fait plus que rafraîchir l'aperçu des libellés — les tarifs par combinaison (Map, clé
   *  "fromIndex-toIndex") n'ont pas besoin d'être redimensionnés comme l'ancien tableau indexé par
   *  tronçon consécutif : les entrées devenues obsolètes (ex. arrêt supprimé) restent simplement
   *  ignorées par legRows(), qui ne regénère que les combinaisons encore valides (voir
   *  AddTripComponent, même pattern). */
  private syncLegPrices() {
    const v = this.tripForm.getRawValue();
    const labels = buildTripCityLabels(
      v.departureCity ?? '',
      v.arrivalCity ?? '',
      v.stops ?? '',
    );
    this.cityLabelsPreview.set(labels);
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
    this.legFaresInvalid.set(false);

    const labels = buildTripCityLabels(
      this.tripForm.value.departureCity ?? '',
      this.tripForm.value.arrivalCity ?? '',
      this.tripForm.value.stops ?? '',
    );
    const last = lastStopIndexFromLabels(labels);
    const rows = this.legRows();
    // Tarifs par tronçon désormais optionnels (toutes les combinaisons, pas seulement
    // consécutives — voir legRows/AddTripComponent) : seul le prix global du trajet reste
    // obligatoire, direct (2 arrêts) ou "trajet complet" (3+ arrêts).
    if (last === 0) {
      const p = Number(this.tripForm.value.price);
      if (p == null || p <= 0 || Number.isNaN(p)) {
        this.notification.show('Indiquez un prix valide pour le trajet.', 'error');
        return;
      }
    } else if (last === 1) {
      // Trajet direct à 2 arrêts : une seule combinaison possible (0-1), c'est elle qui porte le
      // prix du trajet — mandataire comme avant.
      const p = rows[0]?.price ?? 0;
      if (!p || p <= 0 || Number.isNaN(p)) {
        this.legFaresInvalid.set(true);
        this.notification.show('Indiquez un prix valide pour ce trajet.', 'error');
        this.legFaresBlock?.nativeElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
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

    let mainTripPrice: number;
    if (last > 1) {
      const od = Number(formValue.originDestinationPrice);
      if (!Number.isFinite(od) || od <= 0) {
        this.notification.show('Indiquez le prix du trajet complet (départ → arrivée final), positif.', 'error');
        this.isLoading.set(false);
        return;
      }
      mainTripPrice = od;
    } else if (last === 1) {
      mainTripPrice = rows[0]?.price ?? 0;
    } else {
      mainTripPrice = Number(formValue.price ?? 0);
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
      // Voir AddTripComponent.onSubmit — même logique (cityId prioritaire, repli texte "ville
      // introuvable", `stops` toujours envoyé pour que départ/arrivée soient aussi résolus en
      // vraies villes avec coordonnées).
      departureCityId: this.departureSelectedId(),
      arrivalCityId: this.arrivalSelectedId(),
      stops: this.stopsArray.controls
        .map((c) => ({
          cityId: c.get('cityId')!.value as number | null,
          cityName: ((c.get('city')!.value as string) || '').trim(),
        }))
        .filter((s) => s.cityName !== ''),
    };
    if (last > 1) {
      tripPayload['originDestinationPrice'] = mainTripPrice;
    }

    // Toutes les combinaisons ayant un prix renseigné (>0) partent en tarifs optionnels — voir
    // AddTripComponent.onSubmit (même logique, alignée sur create_trip_page.dart).
    tripPayload['legFares'] = rows
      .filter((r) => r.price > 0)
      .map((r) => ({ fromStopIndex: r.fromIndex, toStopIndex: r.toIndex, price: r.price }));
    tripPayload['transportType'] = formValue.transportType ?? 'PUBLIC';

    if (this.showChauffeurPicker()) {
      const aid = formValue.assignedChauffeurId;
      tripPayload['assignedChauffeurId'] = aid != null && aid > 0 ? aid : 0;
    }

    tripPayload['luggagePolicyEnabled'] = formValue.luggagePolicyEnabled === true;
    tripPayload['includedCabinBagsPerPassenger'] = Number(formValue.includedCabinBagsPerPassenger ?? 1);
    tripPayload['includedHoldBagsPerPassenger'] = Number(formValue.includedHoldBagsPerPassenger ?? 1);
    tripPayload['maxExtraHoldBagsPerPassenger'] = Number(formValue.maxExtraHoldBagsPerPassenger ?? 1);
    tripPayload['extraHoldBagPrice'] = Number(formValue.extraHoldBagPrice ?? 0);

    formData.append('trip', new Blob([JSON.stringify(tripPayload)], { type: 'application/json' }));
    if (this.selectedFile) {
      formData.append('vehicleImage', this.selectedFile);
    }

    this.tripService.updateTrip(this.tripId, formData).subscribe({
      next: () => {
        // Toujours brouillon après cette modification : retour à la liste sur l'onglet
        // Brouillon (au lieu de rester sur le formulaire) pour ne pas donner l'impression
        // que le trajet a disparu.
        if (this.tripStatus() === 'DRAFT') {
          this.notification.show('Trajet enregistré — toujours en brouillon.', 'success');
          this.router.navigate([this.basePath(), 'trips'], { queryParams: { status: 'DRAFT' } });
          return;
        }
        this.notification.show('Trajet enregistré ✅', 'success');
        this.router.navigate([this.basePath(), 'trips']);
      },
      error: (err) => {
        this.isLoading.set(false);
        this.notification.show(
          extractApiErrorMessage(err, 'Mise à jour impossible. Vérifie les champs et réessaie.'),
          'error',
        );
        console.error('Erreur Update :', err);
      },
    });
  }

  publish() {
    if (this.isPublishing()) return;
    this.isPublishing.set(true);
    this.tripService.publishTrip(this.tripId).subscribe({
      next: () => {
        this.notification.show('Trajet publié avec succès !', 'success');
        this.router.navigate([this.basePath(), 'trips'], { queryParams: { status: 'PROGRAMMÉ' } });
      },
      error: (err) => {
        this.isPublishing.set(false);
        this.notification.show(extractApiErrorMessage(err, 'Publication impossible. Réessaie.'), 'error');
        console.error('Erreur publication trajet :', err);
      },
    });
  }
}
