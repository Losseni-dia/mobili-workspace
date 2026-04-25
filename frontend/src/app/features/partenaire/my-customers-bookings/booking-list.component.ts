import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { BookingService } from '../../../core/services/booking/booking.service';

@Component({
  selector: 'app-booking-list',
  standalone: true,
  imports: [CommonModule, RouterModule, FormsModule],
  templateUrl: './booking-list.component.html',
  styleUrls: ['./booking-list.component.scss'],
})
export class BookingListComponent implements OnInit {
  private bookingService = inject(BookingService);

  // État des données
  bookings = signal<any[]>([]);
  isLoading = signal(false);

  // État des filtres
  searchTerm = signal('');
  filterDate = signal('');
  filterRoute = signal('');

  ngOnInit(): void {
    this.loadBookings();
  }

  loadBookings(): void {
    this.isLoading.set(true);
    this.bookingService.getPartnerBookings().subscribe({
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

  // Filtrage combiné réactif avec sécurités (null checks)
  filteredBookings = computed(() => {
    const term = (this.searchTerm() || '').toLowerCase();
    const date = this.filterDate();
    const route = this.filterRoute();

    return this.bookings().filter((b) => {
      // Sécurité : on s'assure que les propriétés existent avant toLowerCase()
      const customer = (b.customerName || '').toLowerCase();
      const ref = (b.reference || '').toLowerCase();
      const tripRoute = b.tripRoute || '';

      const matchSearch = customer.includes(term) || ref.includes(term);
      const matchDate = date ? b.date && b.date.startsWith(date) : true;
      const matchRoute = route ? tripRoute === route : true;

      return matchSearch && matchDate && matchRoute;
    });
  });

  // Liste des trajets uniques pour le menu déroulant
  uniqueRoutes = computed(() => {
    return [...new Set(this.bookings().map((b) => b.tripRoute))].filter((r) => !!r);
  });

  // Somme totale des montants affichés
  totalRevenue = computed(() => {
    return this.filteredBookings().reduce((acc, b) => acc + (b.amount || 0), 0);
  });

  getStatusClass(status: string): string {
    return status ? status.toLowerCase() : 'pending';
  }
}
