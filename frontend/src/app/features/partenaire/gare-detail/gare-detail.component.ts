import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterModule } from '@angular/router';
import {
  PartenaireService,
  PartnerDashboard,
  Station,
} from '../../../core/services/partners/partenaire.service';
import { Trip, TripService } from '../../../core/services/trip/trip.service';
import { PartnerTicket, TicketService } from '../../../core/services/ticket/ticket.service';
import { toLocalDateString } from '../../../core/utils/period-range.util';

type TripStatusFilter = 'ALL' | 'DRAFT' | 'EN_COURS' | 'PROGRAMMÉ' | 'TERMINÉ' | 'ANNULÉ';

interface TripWithTickets {
  trip: Trip;
  /** Déjà filtrée des tickets ANNULÉ — un ticket annulé individuellement disparaît complètement
   *  des "tickets pris" de son trajet (même comportement que l'app pro, GareDetailPage). */
  tickets: PartnerTicket[];
}

/**
 * Détail d'une gare pour le dirigeant partenaire — parité avec `GareDetailPage` (mobilipro) :
 * stats du mois, liste des trajets de cette gare avec leurs tickets pris (pas au niveau
 * réservation globale, voir Javadoc de PartnerTicketResponse.tripId), chauffeurs affectés.
 * Web n'avait jusqu'ici que la liste "Mes gares" (CRUD + affectation chauffeur), sans aucun
 * accès aux trajets/tickets par gare (feedback testeur).
 */
@Component({
  selector: 'app-gare-detail',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './gare-detail.component.html',
  styleUrl: './gare-detail.component.scss',
})
export class GareDetailComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private partenaireService = inject(PartenaireService);
  private tripService = inject(TripService);
  private ticketService = inject(TicketService);

  stationId = signal<number | null>(null);
  station = signal<Station | null>(null);
  isLoadingStation = signal(true);

  isLoadingStats = signal(false);
  stats = signal<PartnerDashboard | null>(null);

  isLoadingTrips = signal(false);
  private trips = signal<Trip[]>([]);
  private ticketsByTrip = signal<Map<number, PartnerTicket[]>>(new Map());

  statusFilter = signal<TripStatusFilter>('ALL');
  expandedTripId = signal<number | null>(null);

  readonly STATUS_FILTERS: { value: TripStatusFilter; label: string }[] = [
    { value: 'ALL', label: 'Tous' },
    { value: 'DRAFT', label: 'Brouillon' },
    { value: 'PROGRAMMÉ', label: 'Programmé' },
    { value: 'EN_COURS', label: 'En cours' },
    { value: 'TERMINÉ', label: 'Terminé' },
    { value: 'ANNULÉ', label: 'Annulé' },
  ];

  tripsWithTickets = computed<TripWithTickets[]>(() => {
    const byTrip = this.ticketsByTrip();
    return this.trips().map((trip) => ({ trip, tickets: byTrip.get(trip.id) || [] }));
  });

  filteredTrips = computed(() => {
    const status = this.statusFilter();
    const list = this.tripsWithTickets();
    if (status === 'ALL') return list;
    return list.filter((t) => (t.trip.status || '').toUpperCase() === status);
  });

  ngOnInit(): void {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    if (!id) {
      this.isLoadingStation.set(false);
      return;
    }
    this.stationId.set(id);
    this.loadStation(id);
    this.loadStats(id);
    this.loadTripsAndTickets(id);
  }

  private loadStation(id: number): void {
    this.isLoadingStation.set(true);
    this.partenaireService.listStations().subscribe({
      next: (list) => {
        this.station.set(list.find((s) => s.id === id) || null);
        this.isLoadingStation.set(false);
      },
      error: () => {
        this.station.set(null);
        this.isLoadingStation.set(false);
      },
    });
  }

  private loadStats(id: number): void {
    this.isLoadingStats.set(true);
    this.partenaireService.getDashboardStats(id).subscribe({
      next: (data) => {
        this.stats.set(data);
        this.isLoadingStats.set(false);
      },
      error: () => {
        this.stats.set(null);
        this.isLoadingStats.set(false);
      },
    });
  }

  private loadTripsAndTickets(id: number): void {
    this.isLoadingTrips.set(true);

    this.tripService.getPartnerTrips().subscribe({
      next: (trips) => {
        this.trips.set(
          trips
            .filter((t) => t.stationId === id)
            .sort((a, b) => new Date(b.departureDateTime).getTime() - new Date(a.departureDateTime).getTime()),
        );
      },
      error: () => this.trips.set([]),
    });

    // Bornes larges (2 ans passés → 1 an à venir) pour couvrir tout l'historique des trajets de
    // cette gare, comme côté app pro (GareDetailPage) — /trips/my-trips n'a lui-même pas de
    // filtre de date.
    const now = new Date();
    const from = toLocalDateString(new Date(now.getFullYear() - 2, now.getMonth(), now.getDate()));
    const to = toLocalDateString(new Date(now.getFullYear() + 1, now.getMonth(), now.getDate()));

    this.ticketService.getPartnerTicketsInRange(from, to, id).subscribe({
      next: (tickets) => {
        // Un ticket ANNULÉ individuellement est retiré ici, avant tout regroupement par
        // trajet — il ne doit plus jamais apparaître comme "ticket pris" sur son trajet.
        const byTrip = new Map<number, PartnerTicket[]>();
        for (const t of tickets) {
          if ((t.status || '').toUpperCase() === 'ANNULÉ') continue;
          if (t.tripId == null) continue;
          const list = byTrip.get(t.tripId) || [];
          list.push(t);
          byTrip.set(t.tripId, list);
        }
        this.ticketsByTrip.set(byTrip);
        this.isLoadingTrips.set(false);
      },
      error: () => {
        this.ticketsByTrip.set(new Map());
        this.isLoadingTrips.set(false);
      },
    });
  }

  setStatusFilter(s: TripStatusFilter): void {
    this.statusFilter.set(s);
  }

  toggleTrip(tripId: number): void {
    this.expandedTripId.update((cur) => (cur === tripId ? null : tripId));
  }

  /** Vente brute compagnie du trajet — ticket.grossAmount en priorité, jamais amountPaid seul
   *  (inclut le forfait client). */
  ticketAmount(t: PartnerTicket): number {
    return t.grossAmount ?? t.amountPaid ?? 0;
  }

  tripRevenue(item: TripWithTickets): number {
    return item.tickets
      .filter((t) => t.bookingStatus === 'CONFIRMED' || t.bookingStatus === 'OFFLINE_SALE')
      .reduce((sum, t) => sum + this.ticketAmount(t), 0);
  }

  tripRevenueOnline(item: TripWithTickets): number {
    return item.tickets
      .filter((t) => t.bookingStatus === 'CONFIRMED')
      .reduce((sum, t) => sum + this.ticketAmount(t), 0);
  }

  tripRevenueOffline(item: TripWithTickets): number {
    return item.tickets
      .filter((t) => t.bookingStatus === 'OFFLINE_SALE')
      .reduce((sum, t) => sum + this.ticketAmount(t), 0);
  }

  /** Canal (guichet/en ligne) pour l'affichage du chip par ticket. */
  ticketChannel(t: PartnerTicket): string {
    return t.bookingStatus === 'OFFLINE_SALE' ? 'Guichet' : 'Mobili';
  }

  statusLabel(status: string | undefined): string {
    switch (status) {
      case 'PROGRAMMÉ':
        return 'Programmé';
      case 'EN_COURS':
        return 'En cours';
      case 'TERMINÉ':
        return 'Terminé';
      case 'ANNULÉ':
        return 'Annulé';
      case 'DRAFT':
        return 'Brouillon';
      default:
        return status ?? '';
    }
  }

  /** Couleur de la pastille de statut (alignée sur trip-management/mobilipro). */
  statusPillClass(status: string | undefined): string {
    switch (status) {
      case 'PROGRAMMÉ':
        return 'type-pill--programme';
      case 'EN_COURS':
        return 'type-pill--en-cours';
      case 'TERMINÉ':
        return 'type-pill--termine';
      case 'ANNULÉ':
        return 'type-pill--annule';
      case 'DRAFT':
        return 'type-pill--draft';
      default:
        return '';
    }
  }
}
