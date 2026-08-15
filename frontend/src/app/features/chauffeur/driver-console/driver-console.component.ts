import { CommonModule } from '@angular/common';
import { Component, computed, effect, inject, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';

import { AuthService } from '../../../core/services/auth/auth.service';
import {
  AlightingPassengerRow,
  ChauffeurTripListItem,
  DriverTripService,
  TripStopRow,
} from '../../../core/services/driver/driver-trip.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { TicketResponse, TicketService } from '../../../core/services/ticket/ticket.service';

const STORAGE_KEY = 'mobili.driver.lastTripId';

@Component({
  selector: 'app-driver-console',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './driver-console.component.html',
  styleUrl: './driver-console.component.scss',
})
export class DriverConsoleComponent implements OnInit {
  private readonly driverTrip = inject(DriverTripService);
  private readonly ticketService = inject(TicketService);
  private readonly notify = inject(NotificationService);
  authService = inject(AuthService);

  // ====== ÉTAT ======
  /** Interne uniquement (reprise après rechargement de page) — jamais saisi manuellement par
   * l'utilisateur, aligné sur mobile qui n'expose aucune saisie manuelle de n° de voyage. */
  private tripIdInput = signal<string | number>(this.readStoredTripId());

  loadedTripId = signal<number | null>(null);
  stops = signal<TripStopRow[] | null>(null);
  selectedStop = signal<number>(0);
  alightings = signal<AlightingPassengerRow[]>([]);
  boardings = signal<AlightingPassengerRow[]>([]);

  /** Onglet "Passagers" (tous les billets du trajet, pas filtrés par arrêt) — mobile : _PassengersTab. */
  tripPassengers = signal<TicketResponse[]>([]);
  isLoadingPassengers = signal<boolean>(false);
  passengerSearch = signal<string>('');

  isLoadingStops = signal<boolean>(false);
  isLoadingAlightings = signal<boolean>(false);
  isLoadingBoardings = signal<boolean>(false);
  busyAction = signal<string | null>(null);
  isUndoing = signal<boolean>(false);

  error = signal<string>('');
  successFlash = signal<string>('');

  /** Réservé aux comptes rôle CHAUFFEUR (API /trips/chauffeur/mine). */
  upcomingTrips = signal<ChauffeurTripListItem[]>([]);
  historyTrips = signal<ChauffeurTripListItem[]>([]);
  overviewLoading = signal(false);
  overviewError = signal<string | null>(null);
  startingTripId = signal<number | null>(null);

  // ====== DÉRIVÉ ======
  selectedStopLabel = computed(() => {
    const idx = this.selectedStop();
    return this.stops()?.find((s) => s.stopIndex === idx)?.cityLabel ?? '—';
  });

  totalAlightings = computed(() => this.alightings().length);

  /** Le backend renvoie l'enum français (VALIDÉ/UTILISÉ/ANNULÉ/ARRIVÉ), jamais 'USED'. */
  alightedDone = computed(
    () => this.alightings().filter((a) => a.ticketStatus === 'UTILISÉ').length,
  );

  alightedRemaining = computed(() => Math.max(0, this.totalAlightings() - this.alightedDone()));

  isLastStop = computed(() => {
    const stops = this.stops();
    if (!stops || stops.length === 0) return false;
    const last = Math.max(...stops.map((s) => s.stopIndex));
    return this.selectedStop() === last;
  });

  /** Stats calculées 100% côté client sur la liste brute, alignées sur `_PassengersTab` (mobile). */
  passengerStats = computed(() => {
    const list = this.tripPassengers();
    const onboard = list.filter((p) => ['UTILISÉ', 'UTILISE'].includes((p.status || '').toUpperCase())).length;
    const arrived = list.filter((p) => ['ARRIVÉ', 'ARRIVE'].includes((p.status || '').toUpperCase())).length;
    const absent = list.filter((p) => ['VALIDÉ', 'VALIDE'].includes((p.status || '').toUpperCase())).length;
    return { total: list.length, onboard, arrived, absent };
  });

  /** Filtre client nom/siège/n° ticket, insensible à la casse — le filtre n'affecte pas les stats. */
  filteredPassengers = computed(() => {
    const term = this.passengerSearch().trim().toLowerCase();
    if (!term) return this.tripPassengers();
    return this.tripPassengers().filter((p) =>
      [p.passengerFullName, p.seatNumber, p.ticketNumber].filter(Boolean).some((v) =>
        String(v).toLowerCase().includes(term),
      ),
    );
  });

  passengerStatusLabel(technical: string | undefined | null): string {
    const s = (technical || '').toUpperCase();
    if (s === 'UTILISÉ' || s === 'UTILISE') return 'À bord';
    if (s === 'ARRIVÉ' || s === 'ARRIVE') return 'Arrivé';
    if (s === 'VALIDÉ' || s === 'VALIDE') return 'Non présenté';
    return technical || '—';
  }

  /** Libellés en français pour l’interface conducteur. */
  statusLabel(technical: string | undefined | null): string {
    if (!technical) return '—';
    const map: Record<string, string> = {
      PROGRAMMÉ: 'Prévu',
      EN_COURS: 'En cours',
      TERMINÉ: 'Terminé',
      ANNULÉ: 'Annulé',
    };
    return map[technical] ?? technical;
  }

  serviceKindLabel(t: ChauffeurTripListItem): string {
    return t.source === 'ASSIGNED' ? 'Ligne' : t.source === 'COVOITURAGE' ? 'Covoiturage' : t.source;
  }

  constructor() {
    effect(() => {
      const tripId = this.loadedTripId();
      const idx = this.selectedStop();
      if (tripId != null) {
        this.fetchAlightings(tripId, idx);
        this.fetchBoardings(tripId, idx);
      }
    });
  }

  ngOnInit(): void {
    if (this.authService.hasRole('CHAUFFEUR') || this.authService.hasRole('ADMIN')) {
      this.loadChauffeurOverview();
    }
  }

  private loadChauffeurOverview() {
    if (!this.authService.hasRole('CHAUFFEUR') && !this.authService.hasRole('ADMIN')) {
      return;
    }
    this.overviewLoading.set(true);
    this.overviewError.set(null);
    this.driverTrip.getChauffeurTripsOverview().subscribe({
      next: (o) => {
        this.upcomingTrips.set(o?.upcoming ?? []);
        this.historyTrips.set(o?.history ?? []);
        this.overviewLoading.set(false);
      },
      error: (e) => {
        this.overviewLoading.set(false);
        this.overviewError.set(e?.error?.message ?? 'Impossible de charger la liste des trajets.');
      },
    });
  }

  /**
   * PROGRAMMÉ : démarrer le service (API) puis ouvrir la console.
   * EN_COURS : reprendre sans nouvel appel start.
   * Aligné sur mobile (`TripDetailChauffeurPage._startTrip()`) : aucune confirmation.
   */
  openService(t: ChauffeurTripListItem) {
    const id = t.id;
    this.error.set('');
    if (t.status === 'EN_COURS') {
      this.tripIdInput.set(id);
      this.loadTrip();
      return;
    }
    this.startingTripId.set(id);
    this.driverTrip.startTrip(id).subscribe({
      next: () => {
        this.startingTripId.set(null);
        this.tripIdInput.set(id);
        this.loadTrip();
        this.loadChauffeurOverview();
      },
      error: (e) => {
        this.startingTripId.set(null);
        this.error.set(e?.error?.message ?? 'Impossible de démarrer le trajet.');
      },
    });
  }

  // ====== ACTIONS ======
  parsedTripId(): number | null {
    const raw = this.tripIdInput();
    const value = raw == null ? '' : String(raw).trim();
    if (value === '') return null;
    const n = Number(value);
    return Number.isFinite(n) && n > 0 ? Math.floor(n) : null;
  }

  loadTrip() {
    const id = this.parsedTripId();
    if (id == null) {
      this.error.set('Identifiant de voyage invalide.');
      return;
    }

    this.error.set('');
    this.isLoadingStops.set(true);
    this.driverTrip.listStops(id).subscribe({
      next: (rows) => {
        this.isLoadingStops.set(false);
        const sorted = [...(rows ?? [])].sort((a, b) => a.stopIndex - b.stopIndex);
        this.stops.set(sorted);
        this.loadedTripId.set(id);
        this.selectedStop.set(sorted.length > 0 ? sorted[0].stopIndex : 0);
        this.persistTripId(id);
        this.loadChauffeurOverview();
        this.loadTripPassengers(id);
        this.flashSuccess(`Voyage #${id} chargé (${sorted.length} arrêts).`);
      },
      error: (e) => {
        this.isLoadingStops.set(false);
        this.error.set(e?.error?.message || 'Impossible de charger ce voyage.');
      },
    });
  }

  selectStop(stopIndex: number) {
    this.selectedStop.set(stopIndex);
  }

  refreshAlightings() {
    const id = this.loadedTripId();
    if (id == null) return;
    this.fetchAlightings(id, this.selectedStop());
  }

  private fetchAlightings(tripId: number, stopIndex: number) {
    this.isLoadingAlightings.set(true);
    this.driverTrip.listAlightings(tripId, stopIndex).subscribe({
      next: (rows) => {
        this.alightings.set(rows ?? []);
        this.isLoadingAlightings.set(false);
      },
      error: () => {
        this.alightings.set([]);
        this.isLoadingAlightings.set(false);
      },
    });
  }

  private fetchBoardings(tripId: number, stopIndex: number) {
    this.isLoadingBoardings.set(true);
    this.driverTrip.listBoardings(tripId, stopIndex).subscribe({
      next: (rows) => {
        this.boardings.set(rows ?? []);
        this.isLoadingBoardings.set(false);
      },
      error: () => {
        this.boardings.set([]);
        this.isLoadingBoardings.set(false);
      },
    });
  }

  private loadTripPassengers(tripId: number) {
    this.isLoadingPassengers.set(true);
    this.ticketService.getByTrip(tripId).subscribe({
      next: (rows) => {
        this.tripPassengers.set(rows ?? []);
        this.isLoadingPassengers.set(false);
      },
      error: () => {
        this.tripPassengers.set([]);
        this.isLoadingPassengers.set(false);
      },
    });
  }

  recordDeparture() {
    const id = this.loadedTripId();
    if (id == null) return;
    const stopIndex = this.selectedStop();
    this.busyAction.set(`departure-${stopIndex}`);
    this.driverTrip.recordDeparture(id, stopIndex).subscribe({
      next: () => {
        this.busyAction.set(null);
        this.flashSuccess(`Départ enregistré depuis « ${this.selectedStopLabel()} ».`);
      },
      error: (e) => {
        this.busyAction.set(null);
        this.error.set(e?.error?.message || 'Impossible d\'enregistrer le départ.');
      },
    });
  }

  /**
   * Annule le dernier départ enregistré (erreur de manip). Recharge intégralement l'itinéraire et
   * les descentes de l'arrêt courant résultant, puisque le statut du trajet peut avoir changé.
   * Aligné sur mobile (`_undoLastDeparture`) : aucune confirmation.
   */
  undoLastDeparture() {
    const id = this.loadedTripId();
    if (id == null || this.isUndoing()) return;
    this.isUndoing.set(true);
    this.error.set('');
    this.driverTrip.undoLastDeparture(id).subscribe({
      next: ({ currentStopIndex }) => {
        this.isUndoing.set(false);
        this.selectedStop.set(currentStopIndex);
        this.flashSuccess('Dernier départ annulé.');
        this.fetchAlightings(id, currentStopIndex);
        this.loadChauffeurOverview();
      },
      error: (e) => {
        this.isUndoing.set(false);
        this.error.set(e?.error?.message || "Impossible d'annuler ce départ.");
      },
    });
  }

  resetTrip() {
    this.loadedTripId.set(null);
    this.stops.set(null);
    this.alightings.set([]);
    this.boardings.set([]);
    this.tripPassengers.set([]);
    this.passengerSearch.set('');
    this.selectedStop.set(0);
    this.error.set('');
    this.loadChauffeurOverview();
  }

  /**
   * Aligné sur mobile (`ChauffeurHistoryPage` → `TripDetailChauffeurPage`) : ouvrir le détail d'un
   * trajet terminé en lecture (itinéraire + liste des passagers), pas d'actions de conduite.
   */
  viewHistoryTrip(t: ChauffeurTripListItem) {
    this.error.set('');
    this.tripIdInput.set(t.id);
    this.loadTrip();
  }

  // ====== HELPERS ======
  isBusy(action: string): boolean {
    return this.busyAction() === action;
  }

  private flashSuccess(msg: string) {
    this.successFlash.set(msg);
    this.notify.show(msg, 'success');
    setTimeout(() => this.successFlash.set(''), 3000);
  }

  private readStoredTripId(): string {
    if (typeof window === 'undefined') return '';
    try {
      return window.localStorage.getItem(STORAGE_KEY) ?? '';
    } catch {
      return '';
    }
  }

  private persistTripId(id: number) {
    if (typeof window === 'undefined') return;
    try {
      window.localStorage.setItem(STORAGE_KEY, String(id));
    } catch {
      /* noop */
    }
  }
}
