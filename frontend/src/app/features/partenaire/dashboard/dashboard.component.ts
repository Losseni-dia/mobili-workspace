import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import {
  PartenaireService,
  PartnerDashboard,
  Station,
} from '../../../core/services/partners/partenaire.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { PartnerTicket, TicketService } from '../../../core/services/ticket/ticket.service';
import { ListPager } from '../../../core/utils/list-pager.util';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, FormsModule],
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.scss'],
})
export class DashboardComponent implements OnInit {
  private partenaireService = inject(PartenaireService);
  private auth = inject(AuthService);
  private ticketService = inject(TicketService);

  /** Infos ticket (pas réservation agrégée) — un booking peut couvrir plusieurs sièges/tickets. */
  recentTickets = signal<PartnerTicket[]>([]);
  /** Pagination "Voir plus" — potentiellement tout le mois de tickets d'un coup. */
  recentTicketsPager = new ListPager(this.recentTickets);
  stations = signal<Station[]>([]);
  /** Dirigeant : filtre des KPI (backend `stationId` optionnel) */
  stationFilter: 'all' | number = 'all';

  /** Split en ligne/guichet — aligné sur `dashboard_partner_page.dart` (carte Revenus). */
  revenueOnline = signal(0);
  revenueOffline = signal(0);
  ticketsSoldCount = signal<number | null>(null);

  stats = [
    { label: 'Voyages actifs', value: '0', color: '#092990' },
    { label: 'Réservations', value: '0', color: '#27ae60' },
    { label: 'Revenus (CFA)', value: '0', color: '#f39c12' },
  ];

  isGareOnly = () => this.auth.hasRole('GARE');

  ngOnInit() {
    this.partenaireService.listStations().subscribe({
      next: (list) => {
        this.stations.set(list);
        this.loadStats();
      },
      error: () => this.loadStats(),
    });
  }

  onStationFilterChange() {
    this.loadStats();
  }

  private loadStats() {
    const sid: number | undefined =
      this.isGareOnly() || this.stationFilter === 'all' ? undefined : this.stationFilter;
    this.partenaireService.getDashboardStats(sid).subscribe({
      next: (data: PartnerDashboard) => {
        this.stats = [
          { label: 'Voyages actifs', value: data.activeTripsCount.toString(), color: '#092990' },
          { label: 'Réservations', value: data.totalBookingsCount.toString(), color: '#27ae60' },
          { label: 'Revenus (CFA)', value: data.totalRevenue.toLocaleString(), color: '#f39c12' },
        ];
        this.revenueOnline.set(data.revenueOnline ?? 0);
        this.revenueOffline.set(data.revenueOffline ?? 0);
      },
      error: (err) => console.error('Erreur stats dashboard :', err),
    });

    const now = new Date();
    const iso = (d: Date) => d.toISOString().slice(0, 10);
    const from = iso(new Date(now.getFullYear(), now.getMonth(), 1));
    const to = iso(new Date(now.getFullYear(), now.getMonth() + 1, 0));
    this.ticketService.getPartnerTicketsInRange(from, to, sid).subscribe({
      next: (tickets) => {
        this.ticketsSoldCount.set(tickets.length);
        // Infos ticket (pas réservation agrégée) : tri du plus récent au plus ancien.
        const sorted = [...tickets].sort(
          (a, b) => new Date(b.bookingDate).getTime() - new Date(a.bookingDate).getTime(),
        );
        this.recentTickets.set(sorted);
        this.recentTicketsPager.reset();
      },
      error: () => {
        this.ticketsSoldCount.set(null);
        this.recentTickets.set([]);
      },
    });
  }
}
