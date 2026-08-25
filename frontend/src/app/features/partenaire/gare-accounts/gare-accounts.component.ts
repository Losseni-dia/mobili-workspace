import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { GareUserItem, PartenaireService, Station } from '../../../core/services/partners/partenaire.service';

/**
 * Gestion des comptes « gare » (utilisateurs rattachés à une station) par le dirigeant —
 * fonctionnalité présente côté mobilipro (onglet « Comptes gare »), absente du web jusqu'ici.
 * Réservé au rôle PARTNER (GareUserController est `@PreAuthorize("hasAuthority('ROLE_PARTNER')")`
 * en entier — un compte GARE ne peut pas gérer d'autres comptes gare).
 */
@Component({
  selector: 'app-gare-accounts',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './gare-accounts.component.html',
  styleUrl: './gare-accounts.component.scss',
})
export class GareAccountsComponent implements OnInit {
  private partenaire = inject(PartenaireService);
  private fb = inject(FormBuilder);

  items = signal<GareUserItem[]>([]);
  stations = signal<Station[]>([]);
  isLoading = signal(false);
  error = signal<string | null>(null);
  createSubmitting = signal(false);
  createError = signal<string | null>(null);
  statusSavingId = signal<number | null>(null);
  statusError = signal<string | null>(null);
  affiliationSavingId = signal<number | null>(null);
  affiliationError = signal<string | null>(null);
  editingId = signal<number | null>(null);
  editSubmitting = signal(false);
  editError = signal<string | null>(null);
  showCreatePassword = signal(false);
  showEditPassword = signal(false);

  toggleCreatePassword() {
    this.showCreatePassword.update((v) => !v);
  }
  toggleEditPassword() {
    this.showEditPassword.update((v) => !v);
  }

  form = this.fb.group({
    firstname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    lastname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    email: this.fb.control('', { nonNullable: true, validators: [Validators.email, Validators.maxLength(255)] }),
    phone: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(20)] }),
    login: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.minLength(2), Validators.maxLength(64)] }),
    password: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.minLength(6), Validators.maxLength(128)] }),
    stationId: this.fb.control<number | null>(null, Validators.required),
  });

  editForm = this.fb.group({
    firstname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    lastname: this.fb.control('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(100)] }),
    email: this.fb.control('', { nonNullable: true, validators: [Validators.email, Validators.maxLength(255)] }),
    phone: this.fb.control('', { nonNullable: true, validators: [Validators.maxLength(20)] }),
    password: this.fb.control('', { nonNullable: true, validators: [Validators.minLength(6), Validators.maxLength(120)] }),
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
    this.partenaire.listGareUsers().subscribe({
      next: (rows) => {
        this.items.set(rows);
        this.isLoading.set(false);
      },
      error: (e) => {
        this.error.set(e?.error?.message || 'Impossible de charger la liste des comptes gare.');
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
      .createGareAccount({
        stationId: v.stationId!,
        firstname: v.firstname.trim(),
        lastname: v.lastname.trim(),
        email: v.email.trim() || undefined,
        phone: v.phone.trim(),
        login: v.login.trim(),
        password: v.password,
      })
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
          this.createSubmitting.set(false);
          this.load();
        },
        error: (e) => {
          this.createError.set(
            e?.error?.message || "Impossible de créer ce compte gare. Vérifiez les données ou l'unicité du login.",
          );
          this.createSubmitting.set(false);
        },
      });
  }

  /** `DELETE` côté backend est un archivage logique (enabled=false), pas une suppression. */
  toggleEnabled(item: GareUserItem) {
    if (this.statusSavingId() != null) return;
    const willDisable = item.enabled;
    const verb = willDisable ? 'archiver' : 'réactiver';
    if (!confirm(`Confirmer : ${verb} le compte de ${item.firstname} ${item.lastname} ?`)) return;

    this.statusError.set(null);
    this.statusSavingId.set(item.id);
    const onDone = () => {
      this.items.update((list) => list.map((x) => (x.id === item.id ? { ...x, enabled: !willDisable } : x)));
      this.statusSavingId.set(null);
    };
    const onError = (e: { error?: { message?: string } }) => {
      this.statusError.set(e?.error?.message || `Impossible de ${verb} ce compte.`);
      this.statusSavingId.set(null);
    };
    if (willDisable) {
      this.partenaire.archiveGareUser(item.id).subscribe({ next: onDone, error: onError });
    } else {
      this.partenaire.reactivateGareUser(item.id).subscribe({ next: onDone, error: onError });
    }
  }

  onAffiliationChange(item: GareUserItem, raw: string) {
    const stationId = Number(raw);
    if (Number.isNaN(stationId) || stationId <= 0) return;
    this.affiliationError.set(null);
    this.affiliationSavingId.set(item.id);
    this.partenaire.updateGareUserAffiliation(item.id, stationId).subscribe({
      next: (row) => {
        this.items.update((list) => list.map((x) => (x.id === row.id ? row : x)));
        this.affiliationSavingId.set(null);
      },
      error: (e) => {
        this.affiliationError.set(e?.error?.message || "Impossible de mettre à jour l'affectation gare.");
        this.affiliationSavingId.set(null);
        this.load();
      },
    });
  }

  startEdit(item: GareUserItem) {
    this.editError.set(null);
    this.editingId.set(item.id);
    this.editForm.reset({
      firstname: item.firstname ?? '',
      lastname: item.lastname ?? '',
      email: item.email ?? '',
      phone: item.phone ?? '',
      password: '',
    });
  }

  cancelEdit() {
    this.editingId.set(null);
    this.editError.set(null);
  }

  saveEdit(item: GareUserItem) {
    if (this.editForm.invalid || this.editSubmitting()) return;
    const v = this.editForm.getRawValue();
    this.editSubmitting.set(true);
    this.editError.set(null);
    this.partenaire
      .updateGareUser(item.id, {
        firstname: v.firstname.trim(),
        lastname: v.lastname.trim(),
        email: v.email.trim() || undefined,
        phone: v.phone.trim() || undefined,
        password: v.password.trim() || undefined,
      })
      .subscribe({
        next: (row) => {
          this.items.update((list) => list.map((x) => (x.id === row.id ? row : x)));
          this.editSubmitting.set(false);
          this.editingId.set(null);
        },
        error: (e) => {
          this.editError.set(e?.error?.message || 'Impossible de mettre à jour ce compte.');
          this.editSubmitting.set(false);
        },
      });
  }
}
