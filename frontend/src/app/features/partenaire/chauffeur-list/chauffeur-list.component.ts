import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormsModule, ReactiveFormsModule, Validators } from '@angular/forms';
import {
  PartenaireService,
  PartnerChauffeurItem,
  Station,
} from '../../../core/services/partners/partenaire.service';
import { AuthService } from '../../../core/services/auth/auth.service';

/** Aligné sur `PersonFilter` (mobile, `_ChauffeursTab`). */
type ChauffeurStatusFilter = 'ALL' | 'ACTIVE' | 'ARCHIVED' | 'UNASSIGNED';

@Component({
  selector: 'app-chauffeur-list',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule],
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
  createIdFront: File | null = null;
  createIdBack: File | null = null;
  createLicenseFront: File | null = null;
  createLicenseBack: File | null = null;
  affiliationSavingId = signal<number | null>(null);
  affiliationError = signal<string | null>(null);
  /** Ligne en cours de désactivation/réactivation (état de chargement du bouton). */
  statusSavingId = signal<number | null>(null);
  statusError = signal<string | null>(null);
  /** Chauffeur dont la fiche est ouverte en édition inline. */
  editingId = signal<number | null>(null);
  editSubmitting = signal(false);
  editError = signal<string | null>(null);

  /** Dirigeant ou compte gare : enregistrement des chauffeurs société. */
  canRegisterChauffeur = () =>
    (this.auth.hasRole('PARTNER') && !this.auth.hasRole('GARE')) || this.auth.hasRole('GARE');

  /** Aligné sur `_SearchAndFilterBar` (mobile). */
  search = signal('');
  statusFilter = signal<ChauffeurStatusFilter>('ALL');

  filteredItems = computed(() => {
    const term = this.search().trim().toLowerCase();
    const status = this.statusFilter();
    return this.items().filter((c) => {
      const matchSearch =
        !term ||
        [c.firstname, c.lastname, c.email, c.phone].filter(Boolean).some((v) => String(v).toLowerCase().includes(term));
      const matchStatus =
        status === 'ALL'
          ? true
          : status === 'ACTIVE'
            ? c.enabled
            : status === 'ARCHIVED'
              ? !c.enabled
              : c.affiliationStationId == null;
      return matchSearch && matchStatus;
    });
  });

  form = this.fb.group({
    firstname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    lastname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    email: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.email, Validators.maxLength(255)] }),
    phone: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.minLength(8), Validators.maxLength(20)] }),
    login: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.minLength(2), Validators.maxLength(80)] }),
    password: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.minLength(8), Validators.maxLength(120)] }),
    stationId: this.fb.control<number | null>(null),
  });

  editForm = this.fb.group({
    firstname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    lastname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    email: this.fb.control('', { nonNullable: true, validators: [Validators.email, Validators.maxLength(255)] }),
    phone: this.fb.control('', { nonNullable: true, validators: [Validators.maxLength(20)] }),
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

  onCreateIdFront(ev: Event) {
    this.createIdFront = (ev.target as HTMLInputElement).files?.[0] ?? null;
  }

  onCreateIdBack(ev: Event) {
    this.createIdBack = (ev.target as HTMLInputElement).files?.[0] ?? null;
  }

  onCreateLicenseFront(ev: Event) {
    this.createLicenseFront = (ev.target as HTMLInputElement).files?.[0] ?? null;
  }

  onCreateLicenseBack(ev: Event) {
    this.createLicenseBack = (ev.target as HTMLInputElement).files?.[0] ?? null;
  }

  onCreateSubmit() {
    if (this.form.invalid || this.createSubmitting()) return;
    if (!this.createIdFront || !this.createIdBack) {
      this.createError.set('Le recto et le verso de la carte d’identité sont obligatoires.');
      return;
    }
    if (!this.createLicenseFront || !this.createLicenseBack) {
      this.createError.set('Le recto et le verso du permis de conduire sont obligatoires.');
      return;
    }
    this.createSubmitting.set(true);
    this.createError.set(null);
    const v = this.form.getRawValue();
    this.partenaire
      .createChauffeur(
        {
          firstname: v.firstname.trim(),
          lastname: v.lastname.trim(),
          email: v.email.trim(),
          phone: v.phone.trim(),
          login: v.login.trim(),
          password: v.password,
          stationId: v.stationId ?? null,
        },
        this.createIdFront,
        this.createIdBack,
        this.createLicenseFront,
        this.createLicenseBack,
      )
      .subscribe({
        next: () => {
          this.form.reset({
            firstname: '',
            lastname: '',
            email: '',
            phone: '',
            login: '',
            password: '',
            stationId: null,
          });
          this.createIdFront = null;
          this.createIdBack = null;
          this.createLicenseFront = null;
          this.createLicenseBack = null;
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

  /** Bascule actif/désactivé — `delete` côté backend est une désactivation logique (enabled=false). */
  toggleEnabled(chauffeur: PartnerChauffeurItem) {
    if (this.statusSavingId() != null) return;
    const willDisable = chauffeur.enabled;
    const verb = willDisable ? 'désactiver' : 'réactiver';
    if (!confirm(`Confirmer : ${verb} le compte de ${chauffeur.firstname} ${chauffeur.lastname} ?`)) return;

    this.statusError.set(null);
    this.statusSavingId.set(chauffeur.id);
    const onDone = () => {
      this.items.update((list) =>
        list.map((x) => (x.id === chauffeur.id ? { ...x, enabled: !willDisable } : x)),
      );
      this.statusSavingId.set(null);
    };
    const onError = (e: { error?: { message?: string } }) => {
      this.statusError.set(e?.error?.message || `Impossible de ${verb} ce compte.`);
      this.statusSavingId.set(null);
    };
    if (willDisable) {
      this.partenaire.deleteChauffeur(chauffeur.id).subscribe({ next: onDone, error: onError });
    } else {
      this.partenaire.reactivateChauffeur(chauffeur.id).subscribe({ next: onDone, error: onError });
    }
  }

  startEdit(chauffeur: PartnerChauffeurItem) {
    this.editError.set(null);
    this.editingId.set(chauffeur.id);
    this.editForm.reset({
      firstname: chauffeur.firstname ?? '',
      lastname: chauffeur.lastname ?? '',
      email: chauffeur.email ?? '',
      phone: chauffeur.phone ?? '',
    });
  }

  cancelEdit() {
    this.editingId.set(null);
    this.editError.set(null);
  }

  saveEdit(chauffeur: PartnerChauffeurItem) {
    if (this.editForm.invalid || this.editSubmitting()) return;
    const v = this.editForm.getRawValue();
    this.editSubmitting.set(true);
    this.editError.set(null);
    this.partenaire
      .updateChauffeur(chauffeur.id, {
        firstname: v.firstname.trim(),
        lastname: v.lastname.trim(),
        phone: v.phone.trim() || undefined,
        email: v.email.trim() || undefined,
      })
      .subscribe({
        next: (row) => {
          this.items.update((list) => list.map((x) => (x.id === row.id ? row : x)));
          this.editSubmitting.set(false);
          this.editingId.set(null);
        },
        error: (e) => {
          this.editError.set(e?.error?.message || 'Impossible de mettre à jour ce chauffeur.');
          this.editSubmitting.set(false);
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
