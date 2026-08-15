import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../../core/services/auth/auth.service';
import { PartnerTicket, TicketService } from '../../../core/services/ticket/ticket.service';

type TicketStatusFilter = 'CONFIRME' | 'ANNULE' | 'TOUS';

/** Confirmé = tout statut sauf ANNULÉ (même convention que mobilipro). */
function isConfirmedTicket(status: string | undefined): boolean {
  return (status || '').toUpperCase() !== 'ANNULÉ';
}

/**
 * Vue « tickets » de la gare — remplace les réservations comme action principale gare
 * (parité avec mobilipro : la gare voit les tickets vendus/scannés, pas les réservations,
 * qui restent un concept partenaire/compagnie).
 */
@Component({
  selector: 'app-gare-tickets',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './gare-tickets.component.html',
  styleUrl: './gare-tickets.component.scss',
})
export class GareTicketsComponent implements OnInit {
  private ticketService = inject(TicketService);
  private authService = inject(AuthService);

  tickets = signal<PartnerTicket[]>([]);
  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  search = signal('');
  statusFilter = signal<TicketStatusFilter>('CONFIRME');
  /** Filtrées côté serveur (comme admin-tickets) — vides = 30 derniers jours par défaut côté API. */
  fromDate = signal('');
  toDate = signal('');

  filteredTickets = computed(() => {
    const term = this.search().trim().toLowerCase();
    const status = this.statusFilter();
    return this.tickets().filter((t) => {
      const matchSearch =
        !term ||
        t.ticketNumber.toLowerCase().includes(term) ||
        (t.passengerName || '').toLowerCase().includes(term) ||
        (t.route || '').toLowerCase().includes(term);
      const matchStatus =
        status === 'TOUS' ? true : status === 'CONFIRME' ? isConfirmedTicket(t.status) : !isConfirmedTicket(t.status);
      return matchSearch && matchStatus;
    });
  });

  /**
   * Montant confirmé (vente brute compagnie, jamais le forfait client) — calculé sur TOUS les
   * tickets, indépendamment du filtre de statut actif, jamais gonflé par des tickets annulés.
   */
  confirmedAmount = computed(() =>
    this.tickets()
      .filter((t) => isConfirmedTicket(t.status))
      .reduce((sum, t) => sum + (t.grossAmount ?? t.amountPaid ?? 0), 0),
  );

  ngOnInit(): void {
    this.loadTickets();
  }

  loadTickets(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    const stationId = this.authService.currentUser()?.stationId ?? undefined;
    this.ticketService
      .getPartnerTicketsInRange(this.fromDate() || undefined, this.toDate() || undefined, stationId)
      .subscribe({
      next: (data) => {
        this.tickets.set(data || []);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement tickets gare', err);
        this.errorMessage.set('Impossible de charger les tickets pour le moment.');
        this.isLoading.set(false);
      },
    });
  }

  setStatusFilter(f: TicketStatusFilter): void {
    this.statusFilter.set(f);
  }

  displayAmount(t: PartnerTicket): number {
    return t.grossAmount ?? t.amountPaid ?? 0;
  }
}
