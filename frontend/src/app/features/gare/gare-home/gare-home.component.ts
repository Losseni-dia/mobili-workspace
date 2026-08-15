import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
import { PartenaireService, Station } from '../../../core/services/partners/partenaire.service';
import { TicketService } from '../../../core/services/ticket/ticket.service';

@Component({
  selector: 'app-gare-home',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './gare-home.component.html',
  styleUrl: './gare-home.component.scss',
})
export class GareHomeComponent implements OnInit {
  auth = inject(AuthService);
  private partenaire = inject(PartenaireService);
  private ticketService = inject(TicketService);

  user = computed(() => this.auth.currentUser());
  firstName = computed(() => this.user()?.firstname?.trim() || '');
  stationName = computed(() => this.user()?.stationName || 'Votre gare');
  stationId = computed(() => this.user()?.stationId);

  /** Détail gare (API) dont la liste des chauffeurs affectés. */
  myStation = signal<Station | null>(null);
  stationChauffeursLoading = signal(false);
  stationChauffeursError = signal<string | null>(null);

  gareActionsLocked = computed(
    () => this.auth.hasRole('GARE') && this.auth.currentUser()?.gareOperationsEnabled === false,
  );

  /** Vrai indicateur du jour (au lieu de la grille de liens dupliqués avec la sidebar). */
  todayTicketsLoading = signal(false);
  todayTicketsCount = signal<number | null>(null);
  todayConfirmedAmount = signal<number | null>(null);

  ngOnInit(): void {
    this.auth.fetchUserProfile().subscribe({
      next: () => {
        this.loadStationChauffeurs();
        this.loadTodayTickets();
      },
      error: (e) => {
        console.error('Profil gare (accueil)', e);
        this.loadStationChauffeurs();
        this.loadTodayTickets();
      },
    });
  }

  private loadTodayTickets() {
    if (this.gareActionsLocked()) return;
    this.todayTicketsLoading.set(true);
    const today = new Date().toISOString().slice(0, 10);
    const stationId = this.stationId() ?? undefined;
    this.ticketService.getPartnerTicketsInRange(today, today, stationId).subscribe({
      next: (tickets) => {
        const confirmed = tickets.filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ');
        this.todayTicketsCount.set(confirmed.length);
        this.todayConfirmedAmount.set(
          confirmed.reduce((sum, t) => sum + (t.grossAmount ?? t.amountPaid ?? 0), 0),
        );
        this.todayTicketsLoading.set(false);
      },
      error: () => {
        this.todayTicketsLoading.set(false);
      },
    });
  }

  private loadStationChauffeurs() {
    this.stationChauffeursLoading.set(true);
    this.stationChauffeursError.set(null);
    this.partenaire.listStations().subscribe({
      next: (list) => {
        const sid = this.stationId();
        const row =
          sid != null && sid > 0 ? list.find((s) => s.id === sid) ?? list[0] ?? null : list[0] ?? null;
        this.myStation.set(row);
        this.stationChauffeursLoading.set(false);
      },
      error: (e) => {
        this.stationChauffeursError.set(
          e?.error?.message || 'Impossible de charger les informations de la gare.',
        );
        this.stationChauffeursLoading.set(false);
      },
    });
  }
}
