import { Component, DestroyRef, inject, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, RouterModule } from '@angular/router';
import { of } from 'rxjs';
import { debounceTime, distinctUntilChanged, switchMap } from 'rxjs/operators';
import { PartenaireService, Station } from '../../../core/services/partners/partenaire.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { CityOption, TripService } from '../../../core/services/trip/trip.service';

@Component({
  selector: 'app-station-list',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule],
  templateUrl: './station-list.component.html',
  styleUrl: './station-list.component.scss',
})
export class StationListComponent implements OnInit {
  private partenaire = inject(PartenaireService);
  private auth = inject(AuthService);
  private route = inject(ActivatedRoute);
  private fb = inject(FormBuilder);
  private toast = inject(NotificationService);
  private tripService = inject(TripService);
  private destroyRef = inject(DestroyRef);

  stations = signal<Station[]>([]);
  isLoading = signal(false);
  error = signal<string | null>(null);
  showAddPassword = signal(false);
  showEditPassword = signal(false);

  toggleAddPassword() {
    this.showAddPassword.update((v) => !v);
  }
  toggleEditPassword() {
    this.showEditPassword.update((v) => !v);
  }

  /**
   * Dirigeant (partenaire sans rôle gare) : droits de gestion du réseau. Une gare créée par le
   * partenaire devient active automatiquement (`applyNewStationDefaults`, backend) — pas
   * d'étape d'approbation manuelle.
   */
  isPartnerManager = () => this.auth.hasRole('PARTNER') && !this.auth.hasRole('GARE');

  form = this.fb.nonNullable.group({
    name: ['', Validators.required],
    city: ['', Validators.required],
    /** Optionnel — aligné sur `_StationFormSheet` (mobile) : compte connexion "gare legacy". */
    password: ['', [Validators.minLength(6)]],
  });

  editingId = signal<number | null>(null);
  editSubmitting = signal(false);
  editError = signal<string | null>(null);
  editForm = this.fb.nonNullable.group({
    name: ['', Validators.required],
    city: ['', Validators.required],
    password: ['', [Validators.minLength(6)]],
  });

  /** Redirigé depuis le shell : le dirigeant n'a encore aucune gare (auto-active à la création). */
  needValidationHint = signal(false);

  /**
   * Ville de la gare : autocomplétion restreinte au pays de la société connectée (une gare ne
   * peut être que dans ce pays — StationService.resolveCity impose la même règle côté backend).
   * `*CityId` reste `null` tant que l'utilisateur n'a pas cliqué une suggestion — dans ce cas on
   * soumet le nom tapé tel quel (repli "ville introuvable", voir CityLookupService).
   */
  myCountryId = signal<number | null>(null);
  myCountryName = signal<string | null>(null);
  addCitySuggestions = signal<CityOption[]>([]);
  addSelectedCityId = signal<number | null>(null);
  editCitySuggestions = signal<CityOption[]>([]);
  editSelectedCityId = signal<number | null>(null);

  ngOnInit() {
    this.needValidationHint.set(this.route.snapshot.queryParamMap.get('needValidation') === '1');
    this.load();

    this.partenaire.getMyPartnerInfo().subscribe({
      next: (p) => {
        this.myCountryId.set(p.countryId ?? null);
        this.myCountryName.set(p.countryName ?? null);
      },
      error: (e) => console.error('[station-list] Erreur chargement du pays de la société', e),
    });

    this.form
      .get('city')!
      .valueChanges.pipe(
        debounceTime(200),
        distinctUntilChanged(),
        switchMap((q) => {
          this.addSelectedCityId.set(null);
          const countryId = this.myCountryId();
          if (!countryId || !q || !q.trim()) return of([]);
          return this.tripService.getCitiesByCountry(countryId, q);
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((cities) => this.addCitySuggestions.set(cities));

    this.editForm
      .get('city')!
      .valueChanges.pipe(
        debounceTime(200),
        distinctUntilChanged(),
        switchMap((q) => {
          this.editSelectedCityId.set(null);
          const countryId = this.myCountryId();
          if (!countryId || !q || !q.trim()) return of([]);
          return this.tripService.getCitiesByCountry(countryId, q);
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((cities) => this.editCitySuggestions.set(cities));
  }

  selectAddCity(city: CityOption) {
    this.form.patchValue({ city: city.name });
    this.addSelectedCityId.set(city.id);
    this.addCitySuggestions.set([]);
  }

  selectEditCity(city: CityOption) {
    this.editForm.patchValue({ city: city.name });
    this.editSelectedCityId.set(city.id);
    this.editCitySuggestions.set([]);
  }

  load() {
    this.isLoading.set(true);
    this.partenaire.listStations().subscribe({
      next: (s) => {
        this.stations.set(s);
        this.isLoading.set(false);
      },
      error: (e) => {
        this.error.set(e?.error?.message || 'Impossible de charger les gares');
        this.isLoading.set(false);
      },
    });
  }

  onSubmit() {
    if (this.form.invalid) return;
    const v = this.form.getRawValue();
    const cityId = this.addSelectedCityId();
    this.partenaire
      .createStation({
        name: v.name.trim(),
        ...(cityId ? { cityId } : { cityName: v.city.trim() }),
        password: v.password.trim() || undefined,
      })
      .subscribe({
        next: () => {
          this.form.reset({ name: '', city: '', password: '' });
          this.addSelectedCityId.set(null);
          this.addCitySuggestions.set([]);
          this.load();
        },
        error: (e) => {
          this.toast.show(e?.error?.message || 'Impossible de créer cette gare.', 'error');
          console.error(e);
        },
      });
  }

  startEdit(g: Station) {
    this.editError.set(null);
    this.editingId.set(g.id);
    this.editForm.reset({ name: g.name, city: g.city, password: '' });
    // Pas de cityId connu au départ (Station n'expose que le nom affiché) — si la ville n'est pas
    // retouchée, saveEdit retombe sur cityName qui retrouve la même ville par son nom exact
    // (CityLookupService.resolveOrCreatePending), aucune re-sélection nécessaire.
    this.editSelectedCityId.set(null);
    this.editCitySuggestions.set([]);
  }

  cancelEdit() {
    this.editingId.set(null);
    this.editError.set(null);
    this.editCitySuggestions.set([]);
  }

  // Suppression de gare : endpoint backend (DELETE /partenaire/stations/{id}) et service
  // frontend (PartenaireService.deleteStation) existaient déjà mais n'étaient câblés à aucun
  // bouton — la fonctionnalité était donc invisible côté UI (feedback testeurs).
  pendingDelete = signal<Station | null>(null);
  deleteSubmitting = signal(false);
  deleteError = signal<string | null>(null);

  askDelete(g: Station) {
    this.deleteError.set(null);
    this.pendingDelete.set(g);
  }

  cancelDelete() {
    this.pendingDelete.set(null);
    this.deleteError.set(null);
  }

  confirmDelete() {
    const g = this.pendingDelete();
    if (!g || this.deleteSubmitting()) return;
    this.deleteSubmitting.set(true);
    this.partenaire.deleteStation(g.id).subscribe({
      next: () => {
        this.stations.update((list) => list.filter((x) => x.id !== g.id));
        this.deleteSubmitting.set(false);
        this.pendingDelete.set(null);
        this.toast.show(`Gare « ${g.name} » supprimée.`, 'success');
      },
      error: (e) => {
        this.deleteError.set(e?.error?.message || 'Impossible de supprimer cette gare.');
        this.deleteSubmitting.set(false);
      },
    });
  }

  saveEdit(g: Station) {
    if (this.editForm.invalid || this.editSubmitting()) return;
    const v = this.editForm.getRawValue();
    const cityId = this.editSelectedCityId();
    this.editSubmitting.set(true);
    this.editError.set(null);
    this.partenaire
      .updateStation(g.id, {
        name: v.name.trim(),
        ...(cityId ? { cityId } : { cityName: v.city.trim() }),
        password: v.password.trim() || undefined,
      })
      .subscribe({
        next: (updated) => {
          this.stations.update((list) => list.map((x) => (x.id === updated.id ? updated : x)));
          this.editSubmitting.set(false);
          this.editingId.set(null);
        },
        error: (e) => {
          this.editError.set(e?.error?.message || 'Impossible de mettre à jour cette gare.');
          this.editSubmitting.set(false);
        },
      });
  }

}
