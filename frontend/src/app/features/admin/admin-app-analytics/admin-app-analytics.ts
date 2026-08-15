import { Component, OnInit, computed, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import {
  AdminService,
  AnalyticsRecentEvent,
  AnalyticsSummary,
  DailyLoginStats,
} from '../../../core/services/admin/admin.service';
import { eventTypeLabel } from '../shared/admin-event-labels';

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
  analyticsSummary = signal<AnalyticsSummary | null>(null);
  analyticsLoadError = signal(false);
  analyticsDays = signal<7 | 14 | 30>(30);
  recentEvents = signal<AnalyticsRecentEvent[] | null>(null);
  recentEventsError = signal(false);
  eventSearch = signal('');
  /** Le journal charge 200 lignes d'un coup (API) ; on n'en affiche qu'une partie au départ. */
  visibleLimit = signal(50);

  readonly eventTypeLabel = eventTypeLabel;

  filteredEvents = computed(() => {
    const term = this.eventSearch().trim().toLowerCase();
    const all = this.recentEvents() ?? [];
    if (!term) return all;
    return all.filter(
      (e) =>
        e.detail?.toLowerCase().includes(term) ||
        this.eventTypeLabel(e.eventType).toLowerCase().includes(term),
    );
  });

  visibleEvents = computed(() => this.filteredEvents().slice(0, this.visibleLimit()));

  showMoreEvents() {
    this.visibleLimit.update((n) => n + 50);
  }

  onEventSearchChange(v: string) {
    this.eventSearch.set(v);
    this.visibleLimit.set(50);
  }

  ngOnInit() {
    this.adminService.getDailyLoginStats(30).subscribe((d) => this.loginStats.set(d));
    this.loadSummary(30);
    this.adminService.getRecentAnalyticsEvents(200).subscribe({
      next: (rows) => {
        this.recentEventsError.set(false);
        this.recentEvents.set(rows);
      },
      error: () => {
        this.recentEventsError.set(true);
        this.recentEvents.set([]);
      },
    });
  }

  setAnalyticsDays(d: 7 | 14 | 30) {
    this.loadSummary(d);
  }

  private loadSummary(days: 7 | 14 | 30) {
    this.analyticsDays.set(days);
    this.adminService.getAnalyticsSummary(days).subscribe({
      next: (data) => {
        this.analyticsLoadError.set(false);
        this.analyticsSummary.set(data);
      },
      error: () => {
        this.analyticsLoadError.set(true);
        this.analyticsSummary.set({ from: '', days, byType: [] });
      },
    });
  }

  maxLogins(): number {
    const history = this.loginStats()?.history ?? [];
    if (!history.length) return 1;
    return Math.max(...history.map((x) => x.totalLogins), 1);
  }
}
