import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService, AdminTransaction } from '../../../core/services/admin/admin.service';
import { computePeriodRange, PeriodPreset } from '../../../core/utils/period-range.util';
import { ListPager } from '../../../core/utils/list-pager.util';

/**
 * Page Transactions — frais Mobili (forfait), commission prélevée et net compagnie, par
 * réservation payée (CONFIRMED/OFFLINE_SALE). Le backend calcule et stocke ces montants
 * depuis le chantier forfait/commission, mais rien ne les relisait nulle part côté admin
 * avant cette page (confirmé par audit) — même donnée déjà exposée côté mobilipro
 * (admin_transactions_page.dart), consomme GET /admin/stats/transactions/list.
 */
@Component({
  selector: 'app-admin-transactions',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-transactions.html',
  styleUrl: './admin-transactions.scss',
})
export class AdminTransactions implements OnInit {
  private adminService = inject(AdminService);

  transactions = signal<AdminTransaction[]>([]);
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
      (t) =>
        (t.reference || '').toLowerCase().includes(term) ||
        (t.customerName || '').toLowerCase().includes(term) ||
        (t.companyName || '').toLowerCase().includes(term),
    );
  });

  totalServiceFee = computed(() => this.transactions().reduce((sum, t) => sum + (t.serviceFee || 0), 0));
  totalCommission = computed(() => this.transactions().reduce((sum, t) => sum + (t.commissionTotal || 0), 0));
  totalCompanyNet = computed(() => this.transactions().reduce((sum, t) => sum + (t.companyNet || 0), 0));
  totalRevenue = computed(() => this.transactions().reduce((sum, t) => sum + (t.totalPrice || 0), 0));

  /** Pagination "Voir plus" — évite d'afficher toute la liste (potentiellement longue) d'un coup. */
  pager = new ListPager(this.filtered);

  ngOnInit(): void {
    this.setPeriodPreset('month');
  }

  load(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.adminService.getTransactionList(this.fromDate() || undefined, this.toDate() || undefined).subscribe({
      next: (data) => {
        this.transactions.set(data || []);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement transactions (admin)', err);
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
    this.pager.reset();
    this.load();
  }

  onManualDateChange(): void {
    this.activePeriod.set(null);
    this.pager.reset();
    this.load();
  }

  onSearch(v: string): void {
    this.search.set(v);
    this.pager.reset();
  }
}
