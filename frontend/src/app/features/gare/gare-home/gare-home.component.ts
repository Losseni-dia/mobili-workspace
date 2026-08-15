import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth/auth.service';
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
  private ticketService = inject(TicketService);

  user = computed(() => this.auth.currentUser());
  firstName = computed(() => this.user()?.firstname?.trim() || '');
  stationName = computed(() => this.user()?.stationName || 'Votre gare');
  stationId = computed(() => this.user()?.stationId);

  gareActionsLocked = computed(
    () => this.auth.hasRole('GARE') && this.auth.currentUser()?.gareOperationsEnabled === false,
  );

  /** Vrai indicateur du jour (au lieu de la grille de liens dupliqués avec la sidebar). */
  todayTicketsLoading = signal(false);
  todayTicketsCount = signal<number | null>(null);
  todayConfirmedAmount = signal<number | null>(null);

  ngOnInit(): void {
    this.auth.fetchUserProfile().subscribe({
      next: () => this.loadTodayTickets(),
      error: (e) => {
        console.error('Profil gare (accueil)', e);
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
}
