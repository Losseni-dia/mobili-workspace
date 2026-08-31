import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterModule } from '@angular/router';
import { ConfigurationService } from '../../../configurations/services/configuration.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { TripService, Trip } from '../../../core/services/trip/trip.service';
import { getTripPublicListPrice } from '../../../core/utils/trip-public-list-price.util';
import { SeatPickerComponent } from '../../booking/components/seat-picker/seat-picker.component';
import { BookingResponse, BookingService } from '../../../core/services/booking/booking.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { formatVehicleTypeLabel } from '../../../core/constants/vehicle-types';
import { exportToCsv } from '../../../core/utils/csv-export.util';
import { computePeriodRange } from '../../../core/utils/period-range.util';
import { ListPager } from '../../../core/utils/list-pager.util';

/** Aligné sur `_tripFilterItems` (mobile) — valeurs exactes de l'enum backend TripStatus. */
type TripStatusFilter = 'ALL' | 'DRAFT' | 'EN_COURS' | 'PROGRAMMÉ' | 'TERMINÉ' | 'ANNULÉ';
type PeriodFilter = 'today' | 'week' | 'month' | 'custom' | 'day';

@Component({
  selector: 'app-trip-management',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule, SeatPickerComponent],
  templateUrl: './trip-management.component.html',
  styleUrls: ['./trip-management.component.scss'],
})
export class TripManagementComponent implements OnInit {
  private tripService = inject(TripService);
  private bookingService = inject(BookingService);
  private notify = inject(NotificationService);
  private configuration = inject(ConfigurationService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private authService = inject(AuthService);

  /** Ce composant est chargé à la fois sous /partenaire/trips et /gare/trips (même
   *  composant, deux routes — voir business.routes.ts) : les liens "Nouveau trajet" /
   *  "Modifier" doivent rester dans le bon shell, sinon partnerRoleGuard (rôle PARTNER
   *  strict) éjecte un compte gare vers '/' (effet "déconnexion" sans appel réseau). */
  basePath = computed(() => (this.authService.hasRole('GARE') ? '/gare' : '/partenaire'));

  myTrips = signal<Trip[]>([]);
  isLoading = signal(false);
  search = signal('');

  /** Aligné sur mobile (`PartnerPeriodSelector`) : période serveur, statut = filtre client. */
  period = signal<PeriodFilter>('month');
  statusFilter = signal<TripStatusFilter>('ALL');
  /** Dates manuelles utilisées uniquement quand period() === 'custom'. */
  fromDate = signal('');
  toDate = signal('');

  readonly STATUS_FILTERS: { value: TripStatusFilter; label: string }[] = [
    { value: 'ALL', label: 'Tous' },
    { value: 'DRAFT', label: 'Brouillon' },
    { value: 'EN_COURS', label: 'En cours' },
    { value: 'PROGRAMMÉ', label: 'Programmé' },
    { value: 'TERMINÉ', label: 'Historique' },
    { value: 'ANNULÉ', label: 'Annulé' },
  ];

  /** Filtre libre sur ville de départ/arrivée, ID ou plaque — mêmes conventions que booking-list. */
  filteredTrips = computed(() => {
    const q = this.search().trim().toLowerCase();
    const status = this.statusFilter();
    let list = this.myTrips();
    if (status !== 'ALL') {
      list = list.filter((t) => (t.status || '').toUpperCase() === status);
    }
    if (!q) return list;
    return list.filter((t) =>
      [t.departureCity, t.arrivalCity, String(t.id), t.moreInfo]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().includes(q)),
    );
  });

  /** Pagination "Voir plus" — évite d'afficher toute la liste (potentiellement longue) d'un coup. */
  pager = new ListPager(this.filteredTrips);

  onSearch(v: string): void {
    this.search.set(v);
    this.pager.reset();
  }

  /** Lien "Canal" contextuel : /partenaire/trip-channel ou /gare/trip-channel selon l'espace. */
  tripChannelLink(tripId: number): string[] {
    const base = this.router.url.includes('/gare/') ? '/gare' : '/partenaire';
    return [`${base}/trip-channel`, String(tripId)];
  }

  /** Aligné sur mobilipro (export CSV des trajets). */
  exportCsv(): void {
    exportToCsv(
      `trajets-${new Date().toISOString().slice(0, 10)}`,
      this.filteredTrips().map((t) => ({
        ID: t.id,
        Conducteur: this.chauffeurLabel(t),
        Départ: t.departureCity,
        Arrivée: t.arrivalCity,
        Date: t.departureDateTime,
        'Prix (FCFA)': this.listPrice(t),
        'Places disponibles': t.availableSeats,
        'Places totales': t.totalSeats,
        Statut: t.status,
      })),
    );
  }

  /** ID du trajet dont on vient de copier le code chauffeur (pour feedback UI). */
  copiedTripId = signal<number | null>(null);
  /** Trajet en attente de confirmation de suppression (modal stylée, plus de confirm() natif). */
  pendingDelete = signal<Trip | null>(null);
  deletingId = signal<number | null>(null);
  deleteError = signal<string | null>(null);

  // ====== Passagers (aligné sur PassengersSheet mobile) ======
  passengersTrip = signal<Trip | null>(null);
  passengersList = signal<BookingResponse[]>([]);
  isLoadingPassengers = signal(false);

  // Pas de montant ici (revenus déjà visibles dans l'onglet Réservations) : b.amount/totalPrice
  // incluait le forfait client (Booking.serviceFee), jamais reversé à la compagnie — même bug
  // que TicketMapper côté scan. Plutôt que de dupliquer le calcul correct ici, on retire
  // simplement le prix de cette modale, redondant avec la page Réservations.
  passengerStats = computed(() => {
    const list = this.passengersList();
    const totalPassengers = list.reduce((sum, b) => sum + (b.numberOfSeats || 0), 0);
    return { reservations: list.length, totalPassengers };
  });

  // ====== Vente directe / blocage de places (choix produit : plus de nom de passager,
  // contrairement à OfflineSaleSheet mobile — simple sélection + confirmation) ======
  saleTrip = signal<Trip | null>(null);
  saleOccupiedSeats = signal<string[]>([]);
  saleSelectedSeats = signal<string[]>([]);
  saleSubmitting = signal(false);
  saleError = signal<string | null>(null);

  listPrice = getTripPublicListPrice;

  tripVehicleImageSrc(path: string | null | undefined): string {
    return this.configuration.resolveUploadMediaUrl(path ?? null) ?? '';
  }

  chauffeurLabel(t: Trip): string {
    if (t.assignedChauffeurId == null || t.assignedChauffeurId <= 0) {
      return '—';
    }
    const fn = t.assignedChauffeurFirstname?.trim() ?? '';
    const ln = t.assignedChauffeurLastname?.trim() ?? '';
    const s = `${fn} ${ln}`.trim();
    return s || `#${t.assignedChauffeurId}`;
  }

  ngOnInit(): void {
    // Arrivée depuis Publier/Enregistrer (add-trip/trip-edit) : ouvre directement sur
    // l'onglet correspondant (?status=PROGRAMMÉ ou DRAFT) au lieu de "Tous" par défaut.
    const status = this.route.snapshot.queryParamMap.get('status') as TripStatusFilter | null;
    if (status && this.STATUS_FILTERS.some((f) => f.value === status)) {
      this.statusFilter.set(status);
    }
    this.loadTrips();
  }

  setPeriod(p: PeriodFilter) {
    this.period.set(p);
    if (p === 'day') {
      // Préremplit avec la date déjà choisie, sinon aujourd'hui.
      const d = this.fromDate() || new Date().toISOString().slice(0, 10);
      this.fromDate.set(d);
      this.toDate.set(d);
    } else if (p !== 'custom') {
      const { from, to } = computePeriodRange(p);
      this.fromDate.set(from);
      this.toDate.set(to);
    }
    this.pager.reset();
    this.loadTrips();
  }

  /** Passage manuel des dates : bascule automatiquement en mode "Intervalle". */
  onManualDateChange(): void {
    this.period.set('custom');
    this.pager.reset();
    this.loadTrips();
  }

  /** Sélection d'une date précise unique (mode "day") : from = to = date choisie. */
  onSingleDateChange(v: string): void {
    this.fromDate.set(v);
    this.toDate.set(v);
    this.pager.reset();
    this.loadTrips();
  }

  setStatusFilter(s: TripStatusFilter) {
    this.statusFilter.set(s);
    this.pager.reset();
  }

  private periodRange(): { from: string; to: string } {
    const p = this.period();
    if (p === 'custom' || p === 'day') {
      return { from: this.fromDate(), to: this.toDate() };
    }
    return computePeriodRange(p);
  }

  loadTrips(): void {
    this.isLoading.set(true);
    const { from, to } = this.periodRange();
    this.tripService.getPartnerTripsInRange(from, to).subscribe({
      next: (data: Trip[]) => {
        this.myTrips.set(Array.isArray(data) ? data : []);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement mes trajets :', err);
        this.myTrips.set([]);
        this.isLoading.set(false);
      },
    });
  }

  formatVehicleType = formatVehicleTypeLabel;

  /** Étiquette lisible du statut du trajet (alignée sur mobilipro _statusConfig). */
  statusLabel(status: string | undefined): string {
    switch (status) {
      case 'PROGRAMMÉ':
        return 'Programmé';
      case 'EN_COURS':
        return 'En cours';
      case 'TERMINÉ':
        return 'Terminé';
      case 'ANNULÉ':
        return 'Annulé';
      default:
        return status ?? '';
    }
  }

  /** Couleur de la pastille de statut (alignée sur mobilipro _statusConfig). */
  statusPillClass(status: string | undefined): string {
    switch (status) {
      case 'PROGRAMMÉ':
        return 'type-pill--programme';
      case 'EN_COURS':
        return 'type-pill--en-cours';
      case 'TERMINÉ':
        return 'type-pill--termine';
      case 'ANNULÉ':
        return 'type-pill--annule';
      default:
        return '';
    }
  }

  /**
   * Copie l'identifiant du voyage dans le presse-papier
   * (à transmettre au chauffeur pour démarrer sa console).
   */
  copyTripId(tripId: number, ev?: Event) {
    ev?.stopPropagation();
    const value = String(tripId);
    const onSuccess = () => {
      this.copiedTripId.set(tripId);
      this.notify.show(`ID voyage #${tripId} copié — à transmettre au chauffeur.`, 'success');
      setTimeout(() => {
        if (this.copiedTripId() === tripId) this.copiedTripId.set(null);
      }, 2200);
    };

    if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(value).then(onSuccess, () => this.fallbackCopy(value, onSuccess));
    } else {
      this.fallbackCopy(value, onSuccess);
    }
  }

  private fallbackCopy(value: string, onSuccess: () => void) {
    try {
      const ta = document.createElement('textarea');
      ta.value = value;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      onSuccess();
    } catch {
      this.notify.show('Impossible de copier automatiquement, sélectionne le numéro à la main.', 'error');
    }
  }

  askDelete(trip: Trip) {
    this.deleteError.set(null);
    this.pendingDelete.set(trip);
  }

  cancelDelete() {
    this.pendingDelete.set(null);
  }

  confirmDelete() {
    const trip = this.pendingDelete();
    if (!trip || this.deletingId() != null) return;
    this.deletingId.set(trip.id);
    this.deleteError.set(null);
    this.tripService.deleteTrip(trip.id).subscribe({
      next: () => {
        this.myTrips.update((trips) => trips.filter((t) => t.id !== trip.id));
        this.deletingId.set(null);
        this.pendingDelete.set(null);
      },
      error: (err) => {
        console.error('Erreur suppression :', err);
        this.deleteError.set(err?.error?.message || 'Suppression impossible. Réessayez.');
        this.deletingId.set(null);
      },
    });
  }

  // ====== Passagers ======
  passengersError = signal<string | null>(null);

  openPassengers(trip: Trip) {
    this.passengersTrip.set(trip);
    this.passengersList.set([]);
    this.passengersError.set(null);
    this.isLoadingPassengers.set(true);
    this.bookingService.getConfirmedPassengers(trip.id).subscribe({
      next: (list) => {
        this.passengersList.set(list || []);
        this.isLoadingPassengers.set(false);
      },
      error: (err) => {
        console.error('Erreur chargement passagers :', err);
        this.passengersList.set([]);
        // Distingue une vraie erreur serveur d'une liste réellement vide, plutôt que
        // d'afficher silencieusement "Aucun passager" dans les deux cas.
        this.passengersError.set('Impossible de charger les passagers pour le moment.');
        this.isLoadingPassengers.set(false);
      },
    });
  }

  closePassengers() {
    this.passengersTrip.set(null);
  }

  /**
   * Sièges à afficher pour une réservation — repli sur `numberOfSeats` si `seatNumbers`
   * est vide (réservations plus anciennes, ou collection non chargée) : sans ce repli, la
   * modale Passagers restait visuellement vide malgré des réservations bien présentes
   * (passengerStats affichait quand même les bons totaux, seule la liste ne rendait rien).
   */
  seatsForBooking(b: BookingResponse): string[] {
    if (b.seatNumbers && b.seatNumbers.length > 0) return b.seatNumbers;
    const n = b.numberOfSeats || 1;
    return Array.from({ length: n }, () => '—');
  }

  // ====== Vente directe (bloquer des places) ======
  /** Sélection en cours → confirmation → soumission, sans nom de passager (guichet). */
  saleConfirmOpen = signal(false);

  openSale(trip: Trip) {
    this.saleTrip.set(trip);
    this.saleSelectedSeats.set([]);
    this.saleConfirmOpen.set(false);
    this.saleError.set(null);
    this.bookingService.getOccupiedSeats(trip.id).subscribe({
      next: (seats) => this.saleOccupiedSeats.set(seats),
      error: () => this.saleOccupiedSeats.set([]),
    });
  }

  closeSale() {
    this.saleTrip.set(null);
    this.saleConfirmOpen.set(false);
  }

  onSaleSeatsSelected(seats: string[]) {
    this.saleSelectedSeats.set(seats);
  }

  askConfirmSale() {
    if (this.saleSelectedSeats().length === 0) return;
    this.saleConfirmOpen.set(true);
  }

  cancelConfirmSale() {
    this.saleConfirmOpen.set(false);
  }

  confirmSale() {
    const trip = this.saleTrip();
    const seats = this.saleSelectedSeats();
    if (!trip || seats.length === 0 || this.saleSubmitting()) return;

    this.saleSubmitting.set(true);
    this.saleError.set(null);
    this.bookingService
      .createOfflineSale({
        tripId: trip.id,
        numberOfSeats: seats.length,
        selections: seats.map((seatNumber) => ({ seatNumber, passengerName: '' })),
      })
      .subscribe({
        next: () => {
          this.saleSubmitting.set(false);
          this.notify.show(`${seats.length} place${seats.length > 1 ? 's' : ''} bloquée${seats.length > 1 ? 's' : ''}.`, 'success');
          this.closeSale();
          this.loadTrips();
        },
        error: (err) => {
          this.saleSubmitting.set(false);
          this.saleConfirmOpen.set(false);
          this.saleError.set(err?.error?.message || "Impossible de bloquer cette place.");
        },
      });
  }
}
