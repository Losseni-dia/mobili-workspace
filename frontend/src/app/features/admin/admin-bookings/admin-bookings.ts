import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService, AdminBookingListItem } from '../../../core/services/admin/admin.service';
import { TicketResponse, TicketService } from '../../../core/services/ticket/ticket.service';
import { computePeriodRange, PeriodPreset } from '../../../core/utils/period-range.util';
import { ListPager } from '../../../core/utils/list-pager.util';

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

  /** Pagination "Voir plus" — évite d'afficher toute la liste (potentiellement longue) d'un coup. */
  pager = new ListPager(this.filtered);

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
    this.pager.reset();
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

  /**
   * Montant réel de la réservation dans le détail : `amount`/`totalPrice` sont figés à la
   * création et ne bougent pas si un ticket est annulé individuellement ensuite — on recalcule
   * donc à partir des tickets actifs chargés (`t.price` = montant réellement payé pour ce
   * siège), dès qu'ils sont disponibles. Retombe sur `amount`/`totalPrice` tant que le détail
   * charge. Même correctif que côté partenaire (booking-list.component.ts).
   */
  detailsActiveAmount = computed<number | null>(() => {
    const tickets = this.detailsTickets();
    if (!tickets.length) return null;
    return tickets
      .filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ')
      .reduce((sum, t) => sum + (t.price || 0), 0);
  });
}
