import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import {
  PartenaireService,
  PartnerChauffeurItem,
  Station,
} from '../../../core/services/partners/partenaire.service';
import { AuthService } from '../../../core/services/auth/auth.service';

@Component({
  selector: 'app-chauffeur-list',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './chauffeur-list.component.html',
  styleUrl: './chauffeur-list.component.scss',
})
export class ChauffeurListComponent implements OnInit {
  private partenaire = inject(PartenaireService);
  private fb = inject(FormBuilder);
  auth = inject(AuthService);

  items = signal<PartnerChauffeurItem[]>([]);
  stations = signal<Station[]>([]);
  isLoading = signal(false);
  error = signal<string | null>(null);
  createSubmitting = signal(false);
  createError = signal<string | null>(null);
  affiliationSavingId = signal<number | null>(null);
  affiliationError = signal<string | null>(null);

  /** Dirigeant ou compte gare : enregistrement des chauffeurs société. */
  canRegisterChauffeur = () =>
    (this.auth.hasRole('PARTNER') && !this.auth.hasRole('GARE')) || this.auth.hasRole('GARE');

  form = this.fb.group({
    firstname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    lastname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    email: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.email, Validators.maxLength(255)] }),
    login: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.minLength(2), Validators.maxLength(80)] }),
    password: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.minLength(8), Validators.maxLength(120)] }),
    stationId: this.fb.control<number | null>(null),
  });

  ngOnInit() {
    this.partenaire.listStations().subscribe({
      next: (s) => this.stations.set(s),
      error: () => this.stations.set([]),
    });
    this.load();
  }

  load() {
    this.isLoading.set(true);
    this.error.set(null);
    this.partenaire.listChauffeurs().subscribe({
      next: (rows) => {
        this.items.set(rows);
        this.isLoading.set(false);
      },
      error: (e) => {
        this.error.set(
          e?.error?.message || 'Impossible de charger la liste des chauffeurs. Vérifiez le statut de la compagnie.',
        );
        this.isLoading.set(false);
      },
    });
  }

  onCreateSubmit() {
    if (this.form.invalid || this.createSubmitting()) return;
    this.createSubmitting.set(true);
    this.createError.set(null);
    const v = this.form.getRawValue();
    this.partenaire
      .createChauffeur({
        firstname: v.firstname.trim(),
        lastname: v.lastname.trim(),
        email: v.email.trim(),
        login: v.login.trim(),
        password: v.password,
        stationId: v.stationId ?? null,
      })
      .subscribe({
        next: () => {
          this.form.reset({
            firstname: '',
            lastname: '',
            email: '',
            login: '',
            password: '',
            stationId: null,
          });
          this.createSubmitting.set(false);
          this.load();
        },
        error: (e) => {
          this.createError.set(
            e?.error?.message || "Impossible de créer le compte chauffeur. Vérifiez les données ou l'unicité du login.",
          );
          this.createSubmitting.set(false);
        },
      });
  }

  onAffiliationChange(chauffeur: PartnerChauffeurItem, raw: string) {
    if (!this.canRegisterChauffeur()) return;
    const stationId = raw === '' ? null : Number(raw);
    if (Number.isNaN(stationId)) return;
    this.affiliationError.set(null);
    this.affiliationSavingId.set(chauffeur.id);
    this.partenaire.patchChauffeurAffiliation(chauffeur.id, { stationId }).subscribe({
      next: (row) => {
        this.items.update((list) => list.map((x) => (x.id === row.id ? row : x)));
        this.affiliationSavingId.set(null);
      },
      error: (e) => {
        this.affiliationError.set(
          e?.error?.message || "Impossible de mettre à jour l'affectation gare.",
        );
        this.affiliationSavingId.set(null);
        this.load();
      },
    });
  }
}
