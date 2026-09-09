import { Component, computed, DestroyRef, ElementRef, inject, signal, OnInit, ViewChild } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { BehaviorSubject, Subject, combineLatest, of, startWith } from 'rxjs';
import { debounceTime, distinctUntilChanged, map, switchMap } from 'rxjs/operators';

import { buildTripCityLabels, lastStopIndexFromLabels } from '../../../../core/utils/trip-city-labels.util';
import { AuthService } from '../../../../core/services/auth/auth.service';
import {
  isStationReadyForTrips,
  PartenaireService,
  PartnerChauffeurItem,
  Station,
} from '../../../../core/services/partners/partenaire.service';
import { CityOption, TripLegFarePayload, TripService } from '../../../../core/services/trip/trip.service';
import { NotificationService } from '../../../../core/services/notification/notification.service';
import { VEHICLE_TYPE_ENUM_OPTIONS, type VehicleTypeName } from '../../../../core/constants/vehicle-types';
import { extractApiErrorMessage } from '../../../../core/utils/api-error.util';

@Component({
  selector: 'app-add-trip',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule],
  templateUrl: './add-trip.component.html',
  styleUrls: ['./add-trip.component.scss'],
})
export class AddTripComponent implements OnInit {
  private fb = inject(FormBuilder);
  private tripService = inject(TripService);
  private authService = inject(AuthService);
  private partenaireService = inject(PartenaireService);
  private router = inject(Router);
  private notification = inject(NotificationService);
  private destroyRef = inject(DestroyRef);

  /** Ce composant est chargé sous /partenaire/add-trip ET /gare/add-trip (business.routes.ts) :
   *  toute navigation interne doit rester dans le bon shell, sinon partnerRoleGuard (rôle
   *  PARTNER strict) éjecte un compte gare vers '/' (effet "déconnexion" sans appel réseau). */
  basePath = computed(() => (this.authService.hasRole('GARE') ? '/gare' : '/partenaire'));

  selectedFile: File | null = null;
  isLoading = signal(false);
  isPublishing = signal(false);
  /** Sécurité "Enregistrer" / "Publier" : renseigné dès le premier Enregistrer réussi
   *  (trajet créé en DRAFT côté backend) — active le bouton Publier. */
  tripId = signal<number | null>(null);
  /** Voir onSubmit() : tronçon(s) sans prix (ex. après ajout d'une ville étape). */
  legFaresInvalid = signal(false);
  @ViewChild('legFaresBlock') legFaresBlock?: ElementRef<HTMLElement>;

  cityLabelsPreview = signal<string[]>([]);
  /** Prix par combinaison from→to, clé "fromIndex-toIndex" — toutes les combinaisons possibles,
   *  pas seulement consécutives (voir legRows/onSubmit) ; chacune reste obligatoire (>0) avant
   *  enregistrement. */
  legPrices = signal<Map<string, number>>(new Map());

  /**
   * Autocomplétion ville (départ/arrivée/arrêts) restreinte au pays de la société connectée —
   * une gare/un trajet ne peut être que dans ce pays (StationService.resolveCity impose la même
   * règle côté backend). `*SelectedId` reste `null` tant qu'aucune suggestion n'a été cliquée :
   * dans ce cas le nom tapé est soumis tel quel (repli "ville introuvable", voir
   * CityLookupService), jamais bloquant.
   */
  myCountryId = signal<number | null>(null);
  departureSuggestions = signal<CityOption[]>([]);
  departureSelectedId = signal<number | null>(null);
  arrivalSuggestions = signal<CityOption[]>([]);
  arrivalSelectedId = signal<number | null>(null);
  /** Un seul champ actif à la fois pour les suggestions des arrêts (même principe que
   *  home.component.ts departure/arrival). */
  activeStopIndex = signal<number | null>(null);
  stopSuggestions = signal<CityOption[]>([]);
  private stopQuery$ = new Subject<{ index: number; q: string }>();
  /** Voir StationListComponent.countryId$ (même correctif) : sans ça, la recherche exécutée
   *  avant que GET /partners/my-company ait répondu tourne avec countryId=null et ne se relance
   *  jamais toute seule (bug constaté en test : une ville existante jamais trouvée). */
  private countryId$ = new BehaviorSubject<number | null>(null);

  /** Arrêts intermédiaires — remplace le champ texte unique "Villes traversées" (CSV) par une
   *  liste répétable ; `tripForm.get('stops')` reste alimenté en CSV en interne pour ne pas
   *  toucher au calcul des tronçons/aperçu existant (syncLegPrices, buildTripCityLabels). */
  stopsArray = this.fb.array<FormGroup>([]);
  stations = signal<Station[]>([]);
  chauffeurs = signal<PartnerChauffeurItem[]>([]);
  /** Gare choisie (partenaire) pour filtrer la liste des conducteurs. */
  stationFilterId = signal<number | null>(null);
  /** Gares validées par le dirigeant et actives (booléen `validated` côté API + actif). */
  operationalStations = computed(() => this.stations().filter((s) => isStationReadyForTrips(s)));
  showStationPicker = () =>
    this.authService.hasRole('PARTNER') && !this.authService.hasRole('GARE');

  /** Conducteurs qu’on peut proposer (gare = périmètre local ; partenaire = filtre si gare choisie). */
  eligibleChauffeurs = computed(() => {
    const list = this.chauffeurs();
    const u = this.authService.currentUser();
    if (this.authService.hasRole('GARE') && u?.stationId) {
      return list.filter((c) => c.affiliationStationId === u.stationId);
    }
    const sid = this.stationFilterId();
    if (sid != null) {
      return list.filter((c) => c.affiliationStationId === sid);
    }
    return list;
  });

  /** Toutes les combinaisons from→to (pas seulement consécutives) — un passager peut acheter
   *  directement un tronçon non adjacent (ex. Abidjan→Divo) à un tarif dédié, même logique que
   *  create_trip_page.dart (mobilipro). Chaque tarif reste obligatoire (voir onSubmit). */
  legRows = computed(() => {
    const labs = this.cityLabelsPreview();
    const prices = this.legPrices();
    const rows: { fromIndex: number; toIndex: number; fromLabel: string; toLabel: string; price: number }[] = [];
    for (let i = 0; i < labs.length - 1; i++) {
      // Départ/arrivée pas encore saisis (tripForm les rend de toute façon obligatoires avant
      // tout enregistrement, voir onSubmit) : ne pas afficher de combinaison bancale "— → Ville"
      // le temps que le partenaire finisse de remplir le formulaire.
      if (!labs[i]) continue;
      for (let j = i + 1; j < labs.length; j++) {
        if (!labs[j]) continue;
        rows.push({
          fromIndex: i,
          toIndex: j,
          fromLabel: labs[i],
          toLabel: labs[j],
          price: prices.get(`${i}-${j}`) ?? 0,
        });
      }
    }
    return rows;
  });

  /** 2+ tronçons : tarif explicite départ (ville) → arrivée (ville) distinct des tarifs par
   *  combinaison — basé sur le nombre d'arrêts, pas sur legRows() (qui grandit en O(n²) avec les
   *  combinaisons et ne reflète plus directement le nombre de tronçons consécutifs). */
  needsOriginDestinationPrice = computed(() => lastStopIndexFromLabels(this.cityLabelsPreview()) > 1);
  firstCityLabel = computed(() => this.cityLabelsPreview()[0]?.trim() || 'Départ');
  lastCityLabel = computed(
    () => this.cityLabelsPreview()[this.cityLabelsPreview().length - 1]?.trim() || 'Arrivée',
  );

  tripForm = this.fb.group({
    departureCity: ['', Validators.required],
    arrivalCity: ['', Validators.required],
    departureDateTime: ['', Validators.required],
    vehiculePlateNumber: ['', Validators.required],
    boardingPoint: ['', Validators.required],
    stops: [''],
    /** Si aucun tronçon (itinéraire identique) ou saisie simple ; sinon voir `originDestinationPrice` si 2+ tronçons. */
    price: [null as number | null, [Validators.min(0)]],
    /** Premier → dernier arrêt, obligatoire quand 2+ tronçons. */
    originDestinationPrice: [null as number | null, [Validators.min(0)]],
    availableSeats: [18, [Validators.required, Validators.min(1)]],
    // Clé enum (aligné sur les options du <select>, [value]="o.name"), pas le libellé
    // affiché — sinon le select ne pré-sélectionne aucune option au chargement.
    vehicleType: ['MASSA_NORMAL', Validators.required],
    stationId: [null as number | null],
    /** Chauffeur salarié pour ce service (optionnel à la création). */
    assignedChauffeurId: [null as number | null],
    /** PUBLIC = ligne / transport public ; COVOITURAGE */
    transportType: ['PUBLIC' as 'PUBLIC' | 'COVOITURAGE', Validators.required],
    /** Décoché par défaut : tant que le partenaire ne configure rien, la section "Bagages"
     *  ne doit pas apparaître à la réservation (feedback testeurs — trop verbeux/inattendu
     *  sur des trajets où personne n'a choisi de politique bagages). */
    luggagePolicyEnabled: [false],
    includedCabinBagsPerPassenger: [1, [Validators.min(0)]],
    includedHoldBagsPerPassenger: [1, [Validators.min(0)]],
    maxExtraHoldBagsPerPassenger: [1, [Validators.min(0)]],
    extraHoldBagPrice: [0, [Validators.min(0)]],
  });

  ngOnInit() {
    this.authService.fetchUserProfile().subscribe({
      next: (u) => {
        if (this.authService.hasRole('GARE') && u.gareOperationsEnabled === false) {
          void this.router.navigate(['/gare/accueil'], { replaceUrl: true });
          return;
        }
        this.initAddTripForm();
      },
      error: () => this.initAddTripForm(),
    });
  }

  private initAddTripForm() {
    this.partenaireService.listChauffeurs().subscribe({
      next: (list) => this.chauffeurs.set(list),
      error: () => this.chauffeurs.set([]),
    });
    this.partenaireService.getMyPartnerInfo().subscribe({
      next: (p) => {
        this.myCountryId.set(p.countryId ?? null);
        this.countryId$.next(p.countryId ?? null);
      },
      error: (e) => console.error('[add-trip] Erreur chargement du pays de la société', e),
    });
    this.wireCityAutocomplete();
    if (this.showStationPicker()) {
      this.partenaireService.listStations().subscribe({
        next: (s) => {
          this.stations.set(s);
          const op = s.filter((st) => isStationReadyForTrips(st));
          if (op.length === 1) {
            this.tripForm.patchValue({ stationId: op[0].id });
            this.stationFilterId.set(op[0].id);
          }
          this.applyBoardingFromStation();
        },
        error: () => this.stations.set([]),
      });
    } else {
      if (this.authService.hasRole('GARE')) {
        const sid = this.authService.currentUser()?.stationId;
        this.stationFilterId.set(sid != null && sid > 0 ? sid : null);
      }
      this.applyBoardingFromStation();
    }
    this.tripForm.get('stationId')?.valueChanges.subscribe((v) => {
      this.stationFilterId.set(v);
      this.applyBoardingFromStation();
    });
    this.tripForm.get('vehicleType')?.valueChanges.subscribe((type) => {
      this.updateCapacity(type);
    });

    this.syncLegPrices();
    this.tripForm.valueChanges.pipe(startWith(this.tripForm.value)).subscribe(() => this.syncLegPrices());
  }

  /** Lieu d’embarquement = nom de la gare (compte gare) ou gare choisie (partenaire). */
  applyBoardingFromStation(): void {
    const u = this.authService.currentUser();
    if (this.authService.hasRole('GARE') && u?.stationName?.trim()) {
      this.tripForm.patchValue({ boardingPoint: u.stationName.trim() }, { emitEvent: false });
      return;
    }
    if (this.showStationPicker()) {
      const sid = this.tripForm.get('stationId')?.value;
      if (sid != null) {
        const st = this.operationalStations().find((s) => s.id === sid);
        if (st) {
          this.tripForm.patchValue(
            { boardingPoint: `${st.city} — ${st.name}`.trim() },
            { emitEvent: false },
          );
        }
      }
    }
  }

  /** Autocomplétion départ/arrivée/arrêts — GET /trips/cities/by-country filtré sur le pays de la
   *  société connectée (myCountryId). Réinitialise l'ID sélectionné dès que le texte change à la
   *  main, pour que le repli "ville introuvable" (cityId absent, cityName soumis tel quel) ne
   *  s'applique qu'à ce qui a réellement été tapé, jamais à une ancienne sélection périmée. */
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

  /** Reconstruit le CSV `tripForm.get('stops')` depuis stopsArray — réutilisé tel quel par
   *  syncLegPrices/buildTripCityLabels, aucune duplication de cette logique. */
  private syncStopsCsv() {
    const csv = this.stopsArray.controls
      .map((c) => (c.get('city')!.value || '').trim())
      .filter((name) => name !== '')
      .join(',');
    this.tripForm.get('stops')!.setValue(csv);
  }

  onLegPriceInput(fromIndex: number, toIndex: number, ev: Event) {
    const el = ev.target as HTMLInputElement;
    const v = Number(el.value);
    const next = new Map(this.legPrices());
    next.set(`${fromIndex}-${toIndex}`, Number.isNaN(v) || v < 0 ? 0 : v);
    this.legPrices.set(next);
  }

  /** Ne fait plus que rafraîchir l'aperçu des libellés — les tarifs par combinaison (Map,
   *  clé "fromIndex-toIndex") n'ont pas besoin d'être redimensionnés comme l'ancien tableau
   *  indexé par tronçon consécutif : les entrées devenues obsolètes (ex. arrêt supprimé) restent
   *  simplement ignorées par legRows(), qui ne regénère que les combinaisons encore valides. */
  private syncLegPrices() {
    const v = this.tripForm.getRawValue();
    const labels = buildTripCityLabels(
      v.departureCity ?? '',
      v.arrivalCity ?? '',
      v.stops ?? '',
    );
    this.cityLabelsPreview.set(labels);
  }

  /** Aligné sur le backend {@code VehicleType}. */
  vehicleTypeOptions = VEHICLE_TYPE_ENUM_OPTIONS;

  private updateCapacity(type: string | null) {
    if (!type) {
      return;
    }
    const row = VEHICLE_TYPE_ENUM_OPTIONS.find((o) => o.name === type);
    if (row) {
      this.tripForm.patchValue({ availableSeats: row.defaultSeats });
    }
  }

  onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (file) this.selectedFile = file;
  }

  onSubmit() {
    if (this.tripForm.invalid || this.isLoading()) return;
    this.legFaresInvalid.set(false);
    if (this.authService.hasRole('GARE') && this.authService.currentUser()?.gareOperationsEnabled === false) {
      this.notification.show('Votre gare doit être validée par le dirigeant avant publication de trajet.', 'error');
      return;
    }
    if (this.showStationPicker() && this.operationalStations().length === 0) {
      this.notification.show('Aucune gare validée : approuvez une gare dans Partenaire → Gares.', 'error');
      return;
    }

    const labels = buildTripCityLabels(
      this.tripForm.value.departureCity ?? '',
      this.tripForm.value.arrivalCity ?? '',
      this.tripForm.value.stops ?? '',
    );
    const last = lastStopIndexFromLabels(labels);
    const rows = this.legRows();
    // Toutes les combinaisons (pas seulement consécutives — voir legRows) restent obligatoires :
    // chaque tronçon affiché doit avoir un prix strictement positif avant enregistrement.
    if (last === 0) {
      const p = Number(this.tripForm.value.price);
      if (p == null || p <= 0 || Number.isNaN(p)) {
        this.notification.show('Indiquez un prix valide pour le trajet.', 'error');
        return;
      }
    } else if (rows.some((r) => r.price == null || r.price <= 0 || Number.isNaN(r.price))) {
      this.legFaresInvalid.set(true);
      this.notification.show('Indiquez un prix strictement positif pour chaque tronçon.', 'error');
      this.legFaresBlock?.nativeElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
      return;
    }
    if (last > 1) {
      const od = Number(this.tripForm.value.originDestinationPrice);
      if (od == null || od <= 0 || Number.isNaN(od)) {
        this.notification.show(
          `Indiquez le prix du trajet complet (${this.firstCityLabel()} → ${this.lastCityLabel()}), distinct des tronçons.`,
          'error',
        );
        return;
      }
    }

    this.isLoading.set(true);
    const formData = new FormData();
    const formValue = this.tripForm.value;

    const dateInput = new Date(formValue.departureDateTime!);
    const offset = dateInput.getTimezoneOffset() * 60000;
    const localISOTime = new Date(dateInput.getTime() - offset).toISOString().slice(0, 19);

    const currentUser = this.authService.currentUser();

    const partnerId = currentUser?.partnerId || currentUser?.id;

    // Toutes les combinaisons (validées obligatoires ci-dessus) sont envoyées.
    const legFares: TripLegFarePayload[] | undefined =
      rows.length > 0
        ? rows.map((r) => ({ fromStopIndex: r.fromIndex, toStopIndex: r.toIndex, price: r.price }))
        : undefined;

    const mainTripPrice =
      last === 0 ? Number(formValue.price) : last === 1 ? rows[0]?.price ?? 0 : Number(formValue.originDestinationPrice);

    const tripPayload: Record<string, unknown> = {
      partnerId: partnerId,
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
      // Ville choisie dans la liste (voir GET /trips/cities/by-country) — cityId prioritaire côté
      // backend, sinon repli sur le nom tapé (TripService.resolveTripCity, "ville introuvable").
      // `stops` toujours envoyé (même vide) pour que le backend résolve aussi départ/arrivée en
      // vraies villes avec coordonnées (préalable à la durée réelle, voir TripStopSyncService).
      departureCityId: this.departureSelectedId(),
      arrivalCityId: this.arrivalSelectedId(),
      stops: this.stopsArray.controls
        .map((c) => ({
          cityId: c.get('cityId')!.value as number | null,
          cityName: ((c.get('city')!.value as string) || '').trim(),
        }))
        .filter((s) => s.cityName !== ''),
    };
    if (legFares != null) {
      tripPayload['legFares'] = legFares;
    }
    if (last > 1) {
      tripPayload['originDestinationPrice'] = Number(formValue.originDestinationPrice);
    }
    if (this.showStationPicker() && formValue.stationId != null) {
      tripPayload['stationId'] = formValue.stationId;
    }
    tripPayload['transportType'] = formValue.transportType ?? 'PUBLIC';

    const aid = formValue.assignedChauffeurId;
    if (aid != null && aid > 0) {
      tripPayload['assignedChauffeurId'] = aid;
    }

    tripPayload['luggagePolicyEnabled'] = formValue.luggagePolicyEnabled === true;
    tripPayload['includedCabinBagsPerPassenger'] = Number(formValue.includedCabinBagsPerPassenger ?? 1);
    tripPayload['includedHoldBagsPerPassenger'] = Number(formValue.includedHoldBagsPerPassenger ?? 1);
    tripPayload['maxExtraHoldBagsPerPassenger'] = Number(formValue.maxExtraHoldBagsPerPassenger ?? 1);
    tripPayload['extraHoldBagPrice'] = Number(formValue.extraHoldBagPrice ?? 0);

    const tripBlob = new Blob([JSON.stringify(tripPayload)], { type: 'application/json' });
    formData.append('trip', tripBlob);

    if (this.selectedFile) {
      formData.append('vehicleImage', this.selectedFile);
    }

    if (this.tripId() != null) {
      tripPayload['id'] = this.tripId();
    }

    const id = this.tripId();
    const save$ = id == null ? this.tripService.createTrip(formData) : this.tripService.updateTrip(id, formData);

    save$.subscribe({
      next: (trip) => {
        this.isLoading.set(false);
        this.tripId.set(trip.id);
        this.notification.show('Trajet enregistré — vous pouvez maintenant le publier.', 'success');
      },
      error: (err) => {
        this.isLoading.set(false);
        this.notification.show(
          extractApiErrorMessage(err, 'Enregistrement impossible. Vérifie les champs et réessaie.'),
          'error',
        );
        console.error('Erreur enregistrement trajet :', err);
      },
    });
  }

  publish() {
    const id = this.tripId();
    if (id == null || this.isPublishing()) return;
    this.isPublishing.set(true);
    this.tripService.publishTrip(id).subscribe({
      next: () => {
        this.notification.show('Trajet publié avec succès !', 'success');
        this.router.navigate([this.basePath(), 'trips'], { queryParams: { status: 'PROGRAMMÉ' } });
      },
      error: (err) => {
        this.isPublishing.set(false);
        this.notification.show(
          extractApiErrorMessage(err, 'Publication impossible. Réessaie.'),
          'error',
        );
        console.error('Erreur publication trajet :', err);
      },
    });
  }
}
