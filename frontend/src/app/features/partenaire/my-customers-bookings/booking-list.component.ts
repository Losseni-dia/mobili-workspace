import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';
import { TicketResponse, TicketService } from '../../../core/services/ticket/ticket.service';
import { exportToCsv } from '../../../core/utils/csv-export.util';
import { computePeriodRange, PeriodPreset } from '../../../core/utils/period-range.util';

type BookingStatusFilter = 'CONFIRME' | 'ANNULE' | 'TOUS';

/** Confirmé = argent réellement acquis (CONFIRMED ou vente à la gare OFFLINE_SALE). */
function isConfirmedBooking(status: string | undefined): boolean {
  const s = (status || '').toUpperCase();
  return s === 'CONFIRMED' || s === 'OFFLINE_SALE';
}

function isCancelledBooking(status: string | undefined): boolean {
  return (status || '').toUpperCase() === 'CANCELLED';
}

/**
 * Vente brute réelle (aligné sur `PartnerBookingItem.grossAmount`, mobile). `amount`
 * (Booking.getGrossAmount(), backend) est TOUJOURS recalculé en direct à partir des tickets
 * encore actifs — priorité absolue sur `ticketsTotalAmount`, qui est figé à la création et ne
 * bouge plus si un ticket est annulé individuellement ensuite (montant resté faux en
 * production après une annulation partielle). `ticketsTotalAmount + luggageFee` ne sert plus
 * que de repli pour les réservations antérieures au forfait client, où `amount` peut être
 * absent.
 */
function grossAmount(b: BookingResponse): number {
  if (b.amount != null) return b.amount;
  if (b.ticketsTotalAmount != null) return b.ticketsTotalAmount + (b.luggageFee || 0);
  return b.totalPrice ?? 0;
}

@Component({
  selector: 'app-booking-list',
  standalone: true,
  imports: [CommonModule, RouterModule, FormsModule],
  templateUrl: './booking-list.component.html',
  styleUrls: ['./booking-list.component.scss'],
})
export class BookingListComponent implements OnInit {
  private bookingService = inject(BookingService);
  private ticketService = inject(TicketService);

  // État des données
  bookings = signal<BookingResponse[]>([]);
  isLoading = signal(false);

  // État des filtres
  searchTerm = signal('');
  filterRoute = signal('');
  /** Confirmé par défaut : correspond à ce qui compte réellement comme revenu. */
  statusFilter = signal<BookingStatusFilter>('CONFIRME');

  fromDate = signal('');
  toDate = signal('');
  activePeriod = signal<PeriodPreset | null>('month');

  ngOnInit(): void {
    this.setPeriodPreset('month');
  }

  loadBookings(): void {
    this.isLoading.set(true);
    this.bookingService.getPartnerBookingsInRange(this.fromDate(), this.toDate()).subscribe({
      next: (data) => {
        this.bookings.set(data || []);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement réservations :', err);
        this.isLoading.set(false);
      },
    });
  }

  setPeriodPreset(preset: PeriodPreset): void {
    const { from, to } = computePeriodRange(preset);
    this.activePeriod.set(preset);
    this.fromDate.set(from);
    this.toDate.set(to);
    this.loadBookings();
  }

  onManualDateChange(): void {
    this.activePeriod.set(null);
    this.loadBookings();
  }

  // Filtrage combiné réactif avec sécurités (null checks)
  filteredBookings = computed(() => {
    const term = (this.searchTerm() || '').toLowerCase();
    const route = this.filterRoute();
    const status = this.statusFilter();

    return this.bookings().filter((b) => {
      // Sécurité : on s'assure que les propriétés existent avant toLowerCase()
      const customer = (b.customerName || '').toLowerCase();
      const ref = (b.reference || '').toLowerCase();
      const tripRoute = b.tripRoute || '';

      const matchSearch = customer.includes(term) || ref.includes(term);
      const matchRoute = route ? tripRoute === route : true;
      const matchStatus =
        status === 'TOUS'
          ? true
          : status === 'CONFIRME'
            ? isConfirmedBooking(b.status)
            : isCancelledBooking(b.status);

      return matchSearch && matchRoute && matchStatus;
    });
  });

  // Liste des trajets uniques pour le menu déroulant
  uniqueRoutes = computed(() => {
    return [...new Set(this.bookings().map((b) => b.tripRoute))].filter((r) => !!r);
  });

  // Somme totale des montants affichés (vue filtrée)
  totalRevenue = computed(() => {
    return this.filteredBookings().reduce((acc, b) => acc + grossAmount(b), 0);
  });

  /**
   * Montant réellement acquis : toujours calculé sur les réservations confirmées de la liste
   * complète, indépendamment du filtre de statut actif — jamais gonflé par des réservations
   * annulées ou en attente, même si l'utilisateur bascule sur « Tous » ou « Annulé ».
   */
  confirmedRevenue = computed(() =>
    this.bookings()
      .filter((b) => isConfirmedBooking(b.status))
      .reduce((acc, b) => acc + grossAmount(b), 0),
  );

  displayAmount = grossAmount;

  getStatusClass(status: string): string {
    return status ? status.toLowerCase() : 'pending';
  }

  /** Un ticket annulé individuellement au sein d'une résa multi-sièges encore confirmée. */
  isSeatCancelled(booking: BookingResponse, seat: string): boolean {
    return (booking.cancelledSeatNumbers || []).includes(seat);
  }

  /** Vente à la gare (guichet, sans passage par le paiement en ligne) vs réservation en ligne. */
  saleChannel(b: BookingResponse): string {
    return (b.status || '').toUpperCase() === 'OFFLINE_SALE' ? 'Guichet' : 'Mobili';
  }

  setStatusFilter(f: BookingStatusFilter) {
    this.statusFilter.set(f);
  }

  exportCsv(): void {
    exportToCsv(
      `reservations-${new Date().toISOString().slice(0, 10)}`,
      this.filteredBookings().map((b) => ({
        Référence: b.reference,
        Client: b.customerName,
        Trajet: b.tripRoute,
        Date: b.date,
        Places: b.numberOfSeats,
        'Montant (FCFA)': this.displayAmount(b),
        Canal: this.saleChannel(b),
        Statut: b.status,
      })),
    );
  }

  // ====== Détails (tickets + voyageurs) ======
  detailsBooking = signal<BookingResponse | null>(null);
  detailsTickets = signal<TicketResponse[]>([]);
  isLoadingDetails = signal(false);

  openDetails(booking: BookingResponse) {
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

  /**
   * Montant réel de la réservation dans le détail : `grossAmount(booking)` est figé à la
   * création et ne bouge pas si un ticket est annulé individuellement ensuite — on recalcule
   * donc à partir des tickets actifs chargés (`t.price` = montant réellement payé pour ce
   * siège), dès qu'ils sont disponibles. Retombe sur `grossAmount` tant que le détail charge.
   */
  detailsActiveAmount = computed<number | null>(() => {
    const tickets = this.detailsTickets();
    if (!tickets.length) return null;
    return tickets
      .filter((t) => (t.status || '').toUpperCase() !== 'ANNULÉ')
      .reduce((sum, t) => sum + (t.price || 0), 0);
  });

  closeDetails() {
    this.detailsBooking.set(null);
  }
}
