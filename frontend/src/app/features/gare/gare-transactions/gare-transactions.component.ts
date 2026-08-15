import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { BookingService, PartnerTransaction } from '../../../core/services/booking/booking.service';
import { AuthService } from '../../../core/services/auth/auth.service';

/**
 * Détail financier (frais Mobili/commission, net compagnie) pour la gare connectée — parité
 * mobilipro (« Transactions » gare), endpoint déjà utilisé côté partenaire, ici restreint à
 * la station de l'utilisateur (même convention que gare-tickets).
 */
@Component({
  selector: 'app-gare-transactions',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './gare-transactions.component.html',
  styleUrl: './gare-transactions.component.scss',
})
export class GareTransactionsComponent implements OnInit {
  private bookingService = inject(BookingService);
  private authService = inject(AuthService);

  transactions = signal<PartnerTransaction[]>([]);
  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  fromDate = signal('');
  toDate = signal('');
  search = signal('');

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
    this.load();
  }

  load(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    const stationId = this.authService.currentUser()?.stationId ?? undefined;
    this.bookingService
      .getPartnerTransactionsInRange(this.fromDate() || undefined, this.toDate() || undefined, stationId)
      .subscribe({
        next: (data) => {
          this.transactions.set(data || []);
          this.isLoading.set(false);
        },
        error: (err) => {
          console.error('Erreur chargement transactions gare', err);
          this.errorMessage.set('Impossible de charger les transactions pour le moment.');
          this.isLoading.set(false);
        },
      });
  }
}
