import { Component, computed, inject, OnInit, signal } from '@angular/core';
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
  approvingId = signal<number | null>(null);

  /** Dirigeant (partenaire sans rôle gare) : bouton d’approbation. */
  isPartnerManager = () => this.auth.hasRole('PARTNER') && !this.auth.hasRole('GARE');

  /** Gares à valider (exclut « Validée » par erreur quand l’API ne renvoie pas le statut). */
  pendingStations = computed(() => this.stations().filter((g) => this.isPending(g)));

  form = this.fb.nonNullable.group({
    name: ['', Validators.required],
    city: ['', Validators.required],
  });

  /** Redirigé depuis le shell : il faut au moins une gare validée pour les trajets. */
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
      })
      .subscribe({
        next: () => {
          this.form.reset({ name: '', city: '' });
          this.load();
        },
        error: (e) => console.error(e),
      });
  }

  isPending(g: Station): boolean {
    if (g.validated === true) {
      return false;
    }
    if (g.validated === false) {
      return true;
    }
    if (g.approvalStatus === 'PENDING') {
      return true;
    }
    if (g.approvalStatus != null && g.approvalStatus !== 'PENDING') {
      return false;
    }
    const c = g.code ?? '';
    return c.startsWith('GAR-') && g.active === false;
  }

  approve(g: Station) {
    this.approvingId.set(g.id);
    this.partenaire.approveStation(g.id).subscribe({
      next: () => {
        this.approvingId.set(null);
        this.load();
      },
      error: (e) => {
        this.approvingId.set(null);
        console.error(e);
        this.error.set(e?.error?.message || 'Approbation impossible');
      },
    });
  }
}
