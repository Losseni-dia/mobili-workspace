import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import { PartenaireService, Station } from '../../../core/services/partners/partenaire.service';
import { AuthService } from '../../../core/services/auth/auth.service';

@Component({
  selector: 'app-station-list',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './station-list.component.html',
  styleUrl: './station-list.component.scss',
})
export class StationListComponent implements OnInit {
  private partenaire = inject(PartenaireService);
  private auth = inject(AuthService);
  private route = inject(ActivatedRoute);
  private fb = inject(FormBuilder);

  stations = signal<Station[]>([]);
  isLoading = signal(false);
  error = signal<string | null>(null);

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

  ngOnInit() {
    this.needValidationHint.set(this.route.snapshot.queryParamMap.get('needValidation') === '1');
    this.load();
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
    this.partenaire
      .createStation({
        name: v.name.trim(),
        city: v.city.trim(),
        password: v.password.trim() || undefined,
      })
      .subscribe({
        next: () => {
          this.form.reset({ name: '', city: '', password: '' });
          this.load();
        },
        error: (e) => console.error(e),
      });
  }

  startEdit(g: Station) {
    this.editError.set(null);
    this.editingId.set(g.id);
    this.editForm.reset({ name: g.name, city: g.city, password: '' });
  }

  cancelEdit() {
    this.editingId.set(null);
    this.editError.set(null);
  }

  saveEdit(g: Station) {
    if (this.editForm.invalid || this.editSubmitting()) return;
    const v = this.editForm.getRawValue();
    this.editSubmitting.set(true);
    this.editError.set(null);
    this.partenaire
      .updateStation(g.id, { name: v.name.trim(), city: v.city.trim(), password: v.password.trim() || undefined })
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
