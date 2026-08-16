import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { BookingService, PartnerTransaction } from '../../../core/services/booking/booking.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { exportToCsv } from '../../../core/utils/csv-export.util';
import { computePeriodRange, PeriodPreset } from '../../../core/utils/period-range.util';

/**
 * Vente brute pour la gare connectée — aligné sur `gare_transactions_page.dart` (mobilipro) :
 * la commission Mobili et le net compagnie ne concernent JAMAIS la gare, ils ne sont même pas
 * affichés côté mobile (commentaire explicite dans le code Flutter). Ne jamais réintroduire ces
 * colonnes ici, même si l'endpoint backend (`PartnerTransaction`) les renvoie.
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
  activePeriod = signal<PeriodPreset | null>(null);

  filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    if (!term) return this.transactions();
    return this.transactions().filter(
      (t) => (t.reference || '').toLowerCase().includes(term) || (t.route || '').toLowerCase().includes(term),
    );
  });

  totalGross = computed(() => this.transactions().reduce((sum, t) => sum + (t.grossAmount || 0), 0));

  ngOnInit(): void {
    this.setPeriodPreset('month');
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

  setPeriodPreset(preset: PeriodPreset): void {
    const { from, to } = computePeriodRange(preset);
    this.activePeriod.set(preset);
    this.fromDate.set(from);
    this.toDate.set(to);
    this.load();
  }

  onManualDateChange(): void {
    this.activePeriod.set(null);
    this.load();
  }

  /** Aligné sur mobilipro (export CSV des transactions gare). */
  exportCsv(): void {
    exportToCsv(
      `transactions-gare-${new Date().toISOString().slice(0, 10)}`,
      this.filtered().map((t) => ({
        Référence: t.reference,
        Trajet: t.route,
        Date: t.date,
        Statut: t.status,
        'Montant (FCFA)': t.grossAmount,
      })),
    );
  }
}
