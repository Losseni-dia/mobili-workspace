import { Component, OnInit, computed, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import {
  AdminService,
  AnalyticsRecentEvent,
  AnalyticsSummary,
  DailyLoginStats,
  TopErrorEntry,
} from '../../../core/services/admin/admin.service';
import { eventTypeLabel, eventTypeSeverity, EventSeverity } from '../shared/admin-event-labels';
import { exportToCsv } from '../../../core/utils/csv-export.util';

/** Liste fixe des types connus (backend AnalyticsEventType) — pour le filtre dropdown. */
const KNOWN_EVENT_TYPES = [
  'FAILED_LOGIN',
  'SEARCH_NO_RESULT',
  'BOOKING_CREATED',
  'BOOKING_PAID',
  'TRIP_PUBLISHED',
  'SERVER_ERROR',
];

/** Une entrée du journal groupée avec ses doublons consécutifs (même type + même détail, sans
 *  interruption par un autre événement) — une rafale de 45 exceptions identiques en 2 minutes
 *  devient une ligne « × 45 » au lieu de noyer le journal. */
export interface EventGroup {
  eventType: string;
  detail: string;
  count: number;
  /** Bornes temporelles du groupe — la liste source est triée du plus récent au plus ancien. */
  latestAt: string;
  earliestAt: string;
  sampleId: number;
}

/** Filtre de fenêtre pour le journal détaillé — distinct du sélecteur d'agrégats (7/14/30j) car
 *  le journal veut aussi une vue "tout" (comportement historique : 200 dernières lignes, quelle
 *  que soit leur date) et une vue très courte (24h) pour un incident en cours. */
export type JournalWindow = 'all' | 1 | 7 | 14 | 30;

@Component({
  selector: 'app-admin-app-analytics',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './admin-app-analytics.html',
  styleUrl: './admin-app-analytics.scss',
})
export class AdminAppAnalytics implements OnInit {
  private adminService = inject(AdminService);

  loginStats = signal<DailyLoginStats | null>(null);
  isLoadingLogin = signal(false);

  analyticsSummary = signal<AnalyticsSummary | null>(null);
  analyticsLoadError = signal(false);
  isLoadingSummary = signal(false);
  analyticsDays = signal<7 | 14 | 30>(30);

  topErrors = signal<TopErrorEntry[] | null>(null);
  topErrorsError = signal(false);

  recentEvents = signal<AnalyticsRecentEvent[] | null>(null);
  recentEventsError = signal(false);
  isLoadingJournal = signal(false);
  eventSearch = signal('');
  typeFilter = signal<'all' | string>('all');
  journalWindow = signal<JournalWindow>('all');
  /** Le journal charge 200 lignes d'un coup (API) ; on n'en affiche qu'une partie au départ. */
  visibleLimit = signal(50);

  readonly eventTypeLabel = eventTypeLabel;
  readonly eventTypeSeverity = eventTypeSeverity;
  readonly knownEventTypes = KNOWN_EVENT_TYPES;

  filteredEvents = computed(() => {
    const term = this.eventSearch().trim().toLowerCase();
    const type = this.typeFilter();
    const all = this.recentEvents() ?? [];
    return all.filter((e) => {
      const matchType = type === 'all' || e.eventType === type;
      const matchTerm =
        !term ||
        e.detail?.toLowerCase().includes(term) ||
        this.eventTypeLabel(e.eventType).toLowerCase().includes(term);
      return matchType && matchTerm;
    });
  });

  /** Regroupe les doublons consécutifs (même type + même détail, sans interruption). */
  groupedEvents = computed((): EventGroup[] => {
    const rows = this.filteredEvents();
    const out: EventGroup[] = [];
    for (const row of rows) {
      const last = out[out.length - 1];
      if (last && last.eventType === row.eventType && last.detail === row.detail) {
        last.count++;
        last.earliestAt = row.occurredAt;
      } else {
        out.push({
          eventType: row.eventType,
          detail: row.detail,
          count: 1,
          latestAt: row.occurredAt,
          earliestAt: row.occurredAt,
          sampleId: row.id,
        });
      }
    }
    return out;
  });

  visibleGroups = computed(() => this.groupedEvents().slice(0, this.visibleLimit()));

  /** Taux d'échec de connexion sur la fenêtre choisie — échecs ÷ (échecs + connexions réussies).
   *  Nécessite que loginStats couvre la même fenêtre que analyticsSummary (voir loadAll()). */
  failedLoginRate = computed((): number | null => {
    const summary = this.analyticsSummary();
    const login = this.loginStats();
    if (!summary || !login) return null;
    const failed = summary.byType.find((t) => t.type === 'FAILED_LOGIN')?.count ?? 0;
    const successful = login.history.reduce((sum, d) => sum + d.totalLogins, 0);
    const total = failed + successful;
    return total > 0 ? (failed / total) * 100 : null;
  });

  showMoreEvents() {
    this.visibleLimit.update((n) => n + 50);
  }

  onEventSearchChange(v: string) {
    this.eventSearch.set(v);
    this.visibleLimit.set(50);
  }

  onTypeFilterChange(v: string) {
    this.typeFilter.set(v);
    this.visibleLimit.set(50);
  }

  setJournalWindow(w: JournalWindow) {
    this.journalWindow.set(w);
    this.visibleLimit.set(50);
    this.loadJournal();
  }

  /** Delta % vs période précédente pour un type donné — null si la précédente est vide. */
  deltaFor(type: string): number | null {
    const summary = this.analyticsSummary();
    if (!summary) return null;
    const current = summary.byType.find((t) => t.type === type)?.count ?? 0;
    const previous = summary.previousByType.find((t) => t.type === type)?.count ?? 0;
    if (previous <= 0) return null;
    return ((current - previous) / previous) * 100;
  }

  severityClass(type: string): EventSeverity {
    return this.eventTypeSeverity(type);
  }

  exportJournalCsv() {
    exportToCsv(
      'journal-analyse-app',
      this.filteredEvents().map((e) => ({
        date_heure: e.occurredAt,
        type: this.eventTypeLabel(e.eventType),
        detail: e.detail,
      })),
    );
  }

  ngOnInit() {
    this.loadAll();
    this.loadJournal();
    this.loadTopErrors();
  }

  setAnalyticsDays(d: 7 | 14 | 30) {
    this.analyticsDays.set(d);
    this.loadAll();
    this.loadTopErrors();
  }

  /** Charge connexions + agrégats sur la MÊME fenêtre — nécessaire pour failedLoginRate() et pour
   *  que le graphe de connexions ne reste plus figé à 30 jours quel que soit le sélecteur choisi. */
  private loadAll() {
    const days = this.analyticsDays();
    this.isLoadingLogin.set(true);
    this.adminService.getDailyLoginStats(days).subscribe({
      next: (d) => {
        this.loginStats.set(d);
        this.isLoadingLogin.set(false);
      },
      error: () => this.isLoadingLogin.set(false),
    });

    this.isLoadingSummary.set(true);
    this.adminService.getAnalyticsSummary(days).subscribe({
      next: (data) => {
        this.analyticsLoadError.set(false);
        this.analyticsSummary.set(data);
        this.isLoadingSummary.set(false);
      },
      error: () => {
        this.analyticsLoadError.set(true);
        this.analyticsSummary.set({ from: '', days, byType: [], previousByType: [] });
        this.isLoadingSummary.set(false);
      },
    });
  }

  private loadJournal() {
    this.isLoadingJournal.set(true);
    const w = this.journalWindow();
    this.adminService.getRecentAnalyticsEvents(200, w === 'all' ? null : w).subscribe({
      next: (rows) => {
        this.recentEventsError.set(false);
        this.recentEvents.set(rows);
        this.isLoadingJournal.set(false);
      },
      error: () => {
        this.recentEventsError.set(true);
        this.recentEvents.set([]);
        this.isLoadingJournal.set(false);
      },
    });
  }

  private loadTopErrors() {
    this.adminService.getTopErrors(this.analyticsDays(), 10).subscribe({
      next: (rows) => {
        this.topErrorsError.set(false);
        this.topErrors.set(rows);
      },
      error: () => {
        this.topErrorsError.set(true);
        this.topErrors.set([]);
      },
    });
  }

  maxLogins(): number {
    const history = this.loginStats()?.history ?? [];
    if (!history.length) return 1;
    return Math.max(...history.map((x) => x.totalLogins), 1);
  }
}
