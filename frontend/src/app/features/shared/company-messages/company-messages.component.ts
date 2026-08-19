import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterModule } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { PartenaireService, Station } from '../../../core/services/partners/partenaire.service';
import {
  CreateThreadPayload,
  PartnerGareComMessage,
  PartnerGareComService,
  PartnerGareComThread,
} from '../../../core/services/company-messages/partner-gare-com.service';

@Component({
  selector: 'app-company-messages',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule, RouterModule],
  templateUrl: './company-messages.component.html',
  styleUrl: './company-messages.component.scss',
})
export class CompanyMessagesComponent implements OnInit {
  private pgc = inject(PartnerGareComService);
  private auth = inject(AuthService);
  private partenaire = inject(PartenaireService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private fb = inject(FormBuilder);

  threads = signal<PartnerGareComThread[]>([]);
  messages = signal<PartnerGareComMessage[]>([]);
  selectedId = signal<number | null>(null);
  loading = signal(false);
  loadingMessages = signal(false);
  error = signal<string | null>(null);
  showCreate = signal(false);
  /** Évite un double POST (409 doublon SQL / même titre). */
  creating = signal(false);

  stations = signal<Station[]>([]);
  /** Cases à cocher (ids) pour fil ciblé. */
  selectedStationIds = new Set<number>();

  /**
   * Destinataire côté gare (aligné sur `_CreateThreadDialog`, mobilipro) : soit le partenaire
   * (dirigeant, comportement historique), soit une autre gare de la même compagnie. Auparavant
   * la gare n'avait aucun choix ici — le formulaire envoyait toujours sa PROPRE station en
   * `stationIds`, ce qui revient côté serveur à ne cibler que le partenaire (voir
   * PartnerGareComService.createThread : la cible « autre » n'est ajoutée que si l'id envoyé
   * diffère de la station appelante) — fonctionnellement inoffensif, mais impossible de
   * vraiment écrire à une autre gare, contrairement à l'app mobile.
   */
  gareTarget = signal<'partner' | 'other'>('partner');
  otherStationId = signal<number | null>(null);

  /** Gares de la compagnie hors la sienne (pour cibler « une autre gare »). */
  otherStations = computed(() => {
    const own = this.auth.currentUser()?.stationId;
    return this.stations().filter((s) => s.id !== own);
  });

  /**
   * Partenaire (dirigeant) : peut adresser toutes les gares. Gare seule : seulement sa gare.
   * Une vraie session gare s'authentifie comme StationPrincipal et `/auth/me` renvoie
   * `roles: ["STATION"]`, jamais `"GARE"` (voir UserReadController.buildStationProfile) — le
   * seul `hasRole('GARE')` ne matchait donc plus aucune session gare réelle depuis la migration
   * du login gare vers le code station, et le choix de destinataire ne s'activait jamais.
   */
  canBroadcast = computed(() => this.auth.hasRole('PARTNER'));
  gareOnly = computed(
    () => (this.auth.hasRole('GARE') || this.auth.hasRole('STATION')) && !this.auth.hasRole('PARTNER'),
  );

  newThreadForm = this.fb.nonNullable.group({
    title: ['', [Validators.required, Validators.maxLength(200)]],
    firstMessage: ['', [Validators.required, Validators.maxLength(4000)]],
    scope: ['ALL' as 'ALL' | 'TARGETED'],
  });

  replyForm = this.fb.nonNullable.group({
    body: ['', [Validators.required, Validators.maxLength(4000)]],
  });

  ngOnInit() {
    this.loadThreads();
    this.partenaire.listStations().subscribe({
      next: (s) => this.stations.set(s),
      error: () => this.stations.set([]),
    });
    this.route.queryParamMap.subscribe((q) => {
      const t = q.get('thread');
      if (t) {
        const id = Number(t);
        if (!Number.isNaN(id)) {
          this.selectThread(id, false);
        }
      }
    });
  }

  loadThreads() {
    this.loading.set(true);
    this.pgc.listThreads().subscribe({
      next: (list) => {
        this.threads.set(list);
        this.loading.set(false);
        const tid = this.selectedId();
        if (tid != null && !list.find((x) => x.id === tid)) {
          this.selectedId.set(null);
          this.messages.set([]);
        }
        const fromQuery = this.route.snapshot.queryParamMap.get('thread');
        if (fromQuery) {
          const id = Number(fromQuery);
          if (!Number.isNaN(id) && list.some((l) => l.id === id)) {
            this.selectThread(id, false);
          }
        } else if (list.length === 1 && this.selectedId() == null) {
          this.selectThread(list[0].id, true);
        }
      },
      error: (e) => {
        this.error.set(e?.error?.message || 'Impossible de charger les fils');
        this.loading.set(false);
      },
    });
  }

  private httpErrorMessage(err: { error?: { message?: string } } | null | undefined): string {
    const m = err?.error?.message;
    return typeof m === 'string' && m.trim() ? m.trim() : 'Création impossible';
  }

  openCreate() {
    this.error.set(null);
    this.creating.set(false);
    this.selectedStationIds = new Set();
    this.gareTarget.set('partner');
    this.otherStationId.set(null);
    this.newThreadForm.reset({ title: '', firstMessage: '', scope: 'ALL' });
    if (this.gareOnly()) {
      this.newThreadForm.patchValue({ scope: 'TARGETED' });
    }
    this.showCreate.set(true);
  }

  setGareTarget(target: 'partner' | 'other') {
    this.gareTarget.set(target);
    if (target === 'partner') this.otherStationId.set(null);
  }

  closeCreate() {
    this.showCreate.set(false);
    this.error.set(null);
    this.creating.set(false);
  }

  toggleStation(id: number) {
    if (this.selectedStationIds.has(id)) {
      this.selectedStationIds.delete(id);
    } else {
      this.selectedStationIds.add(id);
    }
  }

  isStationSelected(id: number) {
    return this.selectedStationIds.has(id);
  }

  onCreateSubmit() {
    if (this.newThreadForm.invalid) return;
    const v = this.newThreadForm.getRawValue();
    const payload: CreateThreadPayload = {
      scope: this.gareOnly() ? 'TARGETED' : v.scope,
      title: v.title.trim(),
      firstMessage: v.firstMessage.trim(),
    };
    if (payload.scope === 'TARGETED') {
      if (this.gareOnly()) {
        if (this.gareTarget() === 'other') {
          const other = this.otherStationId();
          if (other == null) {
            this.error.set('Sélectionnez la gare destinataire.');
            return;
          }
          payload.stationIds = [other];
        }
        // Vers le partenaire : pas de stationIds — le dirigeant voit de toute façon
        // tous les fils de sa compagnie (voir PartnerGareComService.listThreads).
      } else {
        payload.stationIds = Array.from(this.selectedStationIds);
        if (payload.stationIds.length === 0) {
          this.error.set('Sélectionnez au moins une gare, ou choisissez « Toutes les gares ».');
          return;
        }
      }
    }
    this.error.set(null);
    this.creating.set(true);
    this.pgc.createThread(payload).subscribe({
      next: (t) => {
        this.creating.set(false);
        this.closeCreate();
        this.loadThreads();
        this.selectThread(t.id, true);
        void this.router.navigate([], { relativeTo: this.route, queryParams: { thread: t.id }, replaceUrl: true });
      },
      error: (e) => {
        this.creating.set(false);
        this.error.set(this.httpErrorMessage(e));
      },
    });
  }

  selectThread(id: number, updateUrl: boolean) {
    this.selectedId.set(id);
    this.loadingMessages.set(true);
    this.pgc.listMessages(id).subscribe({
      next: (m) => {
        this.messages.set(m);
        this.loadingMessages.set(false);
      },
      error: () => {
        this.messages.set([]);
        this.loadingMessages.set(false);
      },
    });
    if (updateUrl) {
      void this.router.navigate([], { relativeTo: this.route, queryParams: { thread: id }, replaceUrl: true });
    }
  }

  onReply() {
    const id = this.selectedId();
    if (id == null || this.replyForm.invalid) return;
    const body = this.replyForm.getRawValue().body.trim();
    this.pgc.postMessage(id, body).subscribe({
      next: () => {
        this.replyForm.reset({ body: '' });
        this.pgc.listMessages(id).subscribe((m) => this.messages.set(m));
        this.loadThreads();
      },
    });
  }

  authorLabel(m: PartnerGareComMessage) {
    const n = (m.authorFirstname + ' ' + m.authorLastname).trim();
    return n || m.authorLogin || '—';
  }

  scopeLabel(t: PartnerGareComThread) {
    if (t.scope === 'ALL') {
      return 'Toutes les gares';
    }
    if (t.stationLabels?.length) {
      return t.stationLabels.join(', ');
    }
    return 'Ciblé';
  }

}
