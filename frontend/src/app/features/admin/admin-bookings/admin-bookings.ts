import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService, AdminBookingListItem } from '../../../core/services/admin/admin.service';
import { TicketResponse, TicketService } from '../../../core/services/ticket/ticket.service';
import { computePeriodRange, PeriodPreset } from '../../../core/utils/period-range.util';

type StatusFilter = 'CONFIRME' | 'ANNULE';

/** Confirmé = argent réellement acquis (CONFIRMED ou vente à la gare OFFLINE_SALE). */
function isConfirmed(status: string | undefined): boolean {
  const s = (status || '').toUpperCase();
  return s === 'CONFIRMED' || s === 'OFFLINE_SALE';
}

function isCancelled(status: string | undefined): boolean {
  return (status || '').toUpperCase() === 'CANCELLED';
}

/**
 * Vue admin des réservations, toutes compagnies confondues — parité avec mobilipro
 * (bookings_stats_page.dart), consomme GET /admin/stats/bookings/list.
 */
@Component({
  selector: 'app-admin-bookings',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-bookings.html',
  styleUrl: './admin-bookings.scss',
})
export class AdminBookings implements OnInit {
  private adminService = inject(AdminService);
  private ticketService = inject(TicketService);

  bookings = signal<AdminBookingListItem[]>([]);
  isLoading = signal(false);
  errorMessage = signal<string | null>(null);

  fromDate = signal('');
  toDate = signal('');
  search = signal('');
  statusFilter = signal<StatusFilter>('CONFIRME');
  activePeriod = signal<PeriodPreset | null>(null);

  filtered = computed(() => {
    const term = this.search().trim().toLowerCase();
    const status = this.statusFilter();
    return this.bookings().filter((b) => {
      const matchSearch =
        !term ||
        (b.reference || '').toLowerCase().includes(term) ||
        (b.customerName || '').toLowerCase().includes(term) ||
        (b.partnerName || '').toLowerCase().includes(term) ||
        (b.route || '').toLowerCase().includes(term);
      const matchStatus = status === 'CONFIRME' ? isConfirmed(b.status) : isCancelled(b.status);
      return matchSearch && matchStatus;
    });
  });

  confirmedAmount = computed(() =>
    this.bookings()
      .filter((b) => isConfirmed(b.status))
      .reduce((sum, b) => sum + (b.amount ?? b.totalPrice ?? 0), 0),
  );

  ngOnInit(): void {
    this.setPeriodPreset('month');
  }

  load(): void {
    this.isLoading.set(true);
    this.errorMessage.set(null);
    this.adminService.getBookingList(this.fromDate() || undefined, this.toDate() || undefined).subscribe({
      next: (data) => {
        this.bookings.set(data || []);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement réservations (admin)', err);
        this.errorMessage.set('Impossible de charger les réservations pour le moment.');
        this.isLoading.set(false);
      },
    });
  }

  setStatusFilter(f: StatusFilter): void {
    this.statusFilter.set(f);
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

  // ====== Détails (tickets + voyageurs) ======
  detailsBooking = signal<AdminBookingListItem | null>(null);
  detailsTickets = signal<TicketResponse[]>([]);
  isLoadingDetails = signal(false);

  openDetails(booking: AdminBookingListItem) {
    this.detailsBooking.set(booking);
    this.detailsTickets.set([]);
    this.isLoadingDetails.set(true);
    this.ticketService.getByBooking(booking.id).subscribe({
      next: (tickets) => {
        this.detailsTickets.set(tickets || []);
        this.isLoadingDetails.set(false);
      },
      error: () => {
        this.detailsTickets.set([]);
        this.isLoadingDetails.set(false);
      },
    });
  }

  closeDetails() {
    this.detailsBooking.set(null);
  }
}
