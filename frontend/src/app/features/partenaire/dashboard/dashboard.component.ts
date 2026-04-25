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

  recentBookings = signal<any[]>([]);
  stations = signal<Station[]>([]);
  /** Dirigeant : filtre des KPI (backend `stationId` optionnel) */
  stationFilter: 'all' | number = 'all';

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
        this.recentBookings.set(data.recentBookings);
      },
      error: (err) => console.error('Erreur stats dashboard :', err),
    });
  }
}
