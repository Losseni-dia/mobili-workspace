import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { BookingService, PartnerTransaction } from '../../../core/services/booking/booking.service';
import { PartenaireService, Station } from '../../../core/services/partners/partenaire.service';

/**
 * Détail financier (frais Mobili/commission, net compagnie) par réservation payée — parité
 * mobilipro (« Transactions » compagnie), endpoint GET /bookings/partner/transactions/range
 * jamais consommé par aucune page web avant ce chantier.
 */
@Component({
  selector: 'app-partner-transactions',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './partner-transactions.component.html',
  styleUrl: './partner-transactions.component.scss',
})
export class PartnerTransactionsComponent implements OnInit {
  private bookingService = inject(BookingService);
  private partenaireService = inject(PartenaireService);

  transactions = signal<PartnerTransaction[]>([]);
  stations = signal<Station[]>([]);
  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  fromDate = signal('');
  toDate = signal('');
  search = signal('');
  stationFilter = signal<number | null>(null);

  filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    if (!term) return this.transactions();
    return this.transactions().filter(
      (t) => (t.reference || '').toLowerCase().includes(term) || (t.route || '').toLowerCase().includes(term),
    );
  });

  totalCommission = computed(() => this.transactions().reduce((sum, t) => sum + (t.commissionTotal || 0), 0));
  totalCompanyNet = computed(() => this.transactions().reduce((sum, t) => sum + (t.companyNet || 0), 0));
  totalGross = computed(() => this.transactions().reduce((sum, t) => sum + (t.grossAmount || 0), 0));

  ngOnInit(): void {
    this.partenaireService.listStations().subscribe({
      next: (s) => this.stations.set(s),
      error: () => this.stations.set([]),
    });
    this.load();
  }

  load(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.bookingService
      .getPartnerTransactionsInRange(this.fromDate() || undefined, this.toDate() || undefined, this.stationFilter() ?? undefined)
      .subscribe({
        next: (data) => {
          this.transactions.set(data || []);
          this.isLoading.set(false);
        },
        error: (err) => {
          console.error('Erreur chargement transactions partenaire', err);
          this.errorMessage.set('Impossible de charger les transactions pour le moment.');
          this.isLoading.set(false);
        },
      });
  }

  onStationFilterChange(raw: string): void {
    this.stationFilter.set(raw === '' ? null : Number(raw));
    this.load();
  }
}
