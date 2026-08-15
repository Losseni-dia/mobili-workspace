import { Component, OnInit, computed, effect, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, FormArray, Validators, ReactiveFormsModule, FormsModule } from '@angular/forms';
import { SeatPickerComponent } from '../../booking/components/seat-picker/seat-picker.component';
import {
  BookingService,
  BookingResponse,
  BookingRequest,
  SeatSelection,
} from '../../../core/services/booking/booking.service';
import { catchError, of } from 'rxjs';
import { ActivatedRoute, Router } from '@angular/router';
import { Trip, TripLegFareResponse, TripService } from '../../../core/services/trip/trip.service';
import { AuthService } from '../../../core/services/auth/auth.service';
import { NotificationService } from '../../../core/services/notification/notification.service';
import { buildTripCityLabels } from '../../../core/utils/trip-city-labels.util';
import { getPricePerSeatForSegment } from '../../../core/utils/trip-segment-price.util';
import { CouponService } from '../../../core/services/coupon/coupon.service';
import { ConfigurationService } from '../../../configurations/services/configuration.service';

@Component({
  selector: 'app-booking-trip',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule, SeatPickerComponent],
  templateUrl: './booking-trip.component.html',
  styleUrl: './booking-trip.component.scss',
})
export class BookingTripComponent implements OnInit {
  private fb = inject(FormBuilder);
  private bookingService = inject(BookingService);
  private route = inject(ActivatedRoute);
  private tripService = inject(TripService);
  private router = inject(Router);
  private authService = inject(AuthService);
  private notificationService = inject(NotificationService);
  private couponService = inject(CouponService);
  private configuration = inject(ConfigurationService);

  tripDetails = signal<Trip | null>(null);
  occupiedSeats = signal<string[]>([]);
  isSubmitting = signal(false);

  /**
   * Covoiturage particulier : même écran de réservation, mais ça reste une DEMANDE envoyée au
   * conducteur (pas de paiement immédiat) — aligné sur `booking_page.dart` (mobile_app), qui
   * bifurque sur `trip.isCovoiturage` sans dupliquer l'écran.
   */
  isCovoiturage = computed(() => this.tripDetails()?.transportType === 'COVOITURAGE');

  driverPhotoUrl = computed(() => {
    const url = this.tripDetails()?.covoiturageOrganizerDriverPhotoUrl;
    return url ? this.configuration.resolveUploadMediaUrl(url) : null;
  });

  driverName = computed(() => {
    const trip = this.tripDetails();
    const fn = trip?.covoiturageOrganizerFirstname?.trim() ?? '';
    const ln = trip?.covoiturageOrganizerLastname?.trim() ?? '';
    return `${fn} ${ln}`.trim() || 'Conducteur';
  });

  /** Libellés des arrêts dans l'ordre (ville de départ → … → ville d'arrivée). */
  stopLabels = signal<string[]>([]);
  /** Tarifs par tronçon consécutif (index → prix). */
  legFares = signal<TripLegFareResponse[]>([]);

  boardingIndex = signal<number>(0);
  alightingIndex = signal<number>(0);
  /** Pour recalculer le plafond bagages quand la sélection de sièges change. */
  selectedSeatCount = signal(0);

  /**
   * Forfait client (100/200/300 FCFA) et total renvoyés par `/bookings/price-preview` —
   * même calcul serveur que la création réelle. `null` tant qu'aucun aperçu n'a réussi
   * (aucun siège choisi, ou appel réseau en échec) : `totalBookingPrice()` retombe alors sur
   * un total local sans forfait plutôt que de bloquer l'affichage.
   */
  serviceFee = signal<number | null>(null);
  private previewTotal = signal<number | null>(null);
  private previewSeq = 0;

  /** Coupon appliqué (validé côté serveur) — envoyé à la fois au preview et à la création. */
  appliedCoupon = signal<string | null>(null);
  couponInput = signal('');
  couponChecking = signal(false);
  couponError = signal<string | null>(null);
  /** Résultat du dernier GET /coupons/{code}/validate réussi — feedback instantané avant preview. */
  couponDiscount = signal<{ originalPrice: number; finalPrice: number } | null>(null);

  bookingForm: FormGroup;
  tripId: number = 0;

  maxExtraHoldForSelection = computed(() => {
    const trip = this.tripDetails();
    const seats = this.selectedSeatCount();
    const perPax = trip?.maxExtraHoldBagsPerPassenger ?? 1;
    return Math.max(0, seats * perPax);
  });

  /** Prix pour une place sur le segment choisi (même règles que le serveur). */
  pricePerSeat = computed(() => {
    const trip = this.tripDetails();
    if (!trip) return 0;
    const last = Math.max(0, this.stopLabels().length - 1);
    return getPricePerSeatForSegment(
      trip,
      this.legFares(),
      this.boardingIndex(),
      this.alightingIndex(),
      last,
    );
  });

  /** Vrai quand l'utilisateur a choisi une portion valide (départ < descente). */
  hasValidSegment = computed(() => {
    const b = this.boardingIndex();
    const a = this.alightingIndex();
    return a > b;
  });

  /** Options de départ : tous les arrêts sauf le dernier. */
  boardingOptions = computed(() => {
    const labels = this.stopLabels();
    return labels.slice(0, Math.max(0, labels.length - 1)).map((label, i) => ({ index: i, label }));
  });

  /** Options de descente : tous les arrêts après l'embarquement. */
  alightingOptions = computed(() => {
    const labels = this.stopLabels();
    const b = this.boardingIndex();
    return labels.slice(b + 1).map((label, i) => ({ index: b + 1 + i, label }));
  });

  constructor() {
    this.bookingForm = this.fb.group({
      passengerNames: this.fb.array([]),
      selectedSeats: this.fb.control([]),
      extraHoldBags: [0, [Validators.min(0)]],
    });

    effect(() => {
      const b = this.boardingIndex();
      const a = this.alightingIndex();
      if (this.tripId && a > b) {
        this.reloadOccupiedSeats(b, a);
        this.bookingForm.patchValue({ selectedSeats: [], extraHoldBags: 0 });
        this.selectedSeatCount.set(0);
        while (this.passengerArray.length) {
          this.passengerArray.removeAt(0);
        }
        this.refreshPricePreview();
      }
    });

    this.bookingForm.get('extraHoldBags')?.valueChanges.subscribe(() => this.refreshPricePreview());
  }

  ngOnInit() {
    this.route.paramMap.subscribe((params) => {
      const id = params.get('id');
      if (id) {
        this.tripId = +id;
        this.loadData();
      }
    });
  }

  private loadData() {
    this.tripDetails.set(null);

    this.tripService.getTripById(this.tripId).subscribe({
      next: (trip: Trip) => {
        this.tripDetails.set(trip);
        const labels = buildTripCityLabels(trip.departureCity, trip.arrivalCity, trip.moreInfo ?? '');
        this.stopLabels.set(labels);
        this.legFares.set(trip.legFares ?? []);
        this.boardingIndex.set(0);
        this.alightingIndex.set(Math.max(0, labels.length - 1));
      },
      error: () => this.notificationService.show('Impossible de charger les détails du trajet.', 'error'),
    });
  }

  private reloadOccupiedSeats(boarding: number, alighting: number) {
    this.bookingService.getOccupiedSeats(this.tripId, boarding, alighting).subscribe({
      next: (seats) => this.occupiedSeats.set(seats || []),
      error: () => this.occupiedSeats.set([]),
    });
  }

  get passengerArray() {
    return this.bookingForm.get('passengerNames') as FormArray;
  }

  onBoardingChange(ev: Event) {
    const raw = (ev.target as HTMLSelectElement).value;
    const idx = Number(raw);
    if (Number.isNaN(idx)) return;
    this.boardingIndex.set(idx);
    if (this.alightingIndex() <= idx) {
      const last = Math.max(0, this.stopLabels().length - 1);
      this.alightingIndex.set(Math.min(last, idx + 1));
    }
  }

  onAlightingChange(ev: Event) {
    const raw = (ev.target as HTMLSelectElement).value;
    const idx = Number(raw);
    if (Number.isNaN(idx)) return;
    this.alightingIndex.set(idx);
  }

  onSeatToggle(seats: string[]) {
    this.bookingForm.patchValue({ selectedSeats: seats });
    this.selectedSeatCount.set(seats.length);
    const currentCount = this.passengerArray.length;
    const nextCount = seats.length;

    if (nextCount > currentCount) {
      for (let i = 0; i < nextCount - currentCount; i++) {
        this.passengerArray.push(this.fb.control('', Validators.required));
      }
    } else {
      for (let i = 0; i < currentCount - nextCount; i++) {
        this.passengerArray.removeAt(this.passengerArray.length - 1);
      }
    }

    const cap = this.maxExtraHoldForSelection();
    const cur = Number(this.bookingForm.get('extraHoldBags')?.value ?? 0);
    if (!Number.isNaN(cur) && cur > cap) {
      this.bookingForm.patchValue({ extraHoldBags: cap });
    }
    this.refreshPricePreview();
  }

  /**
   * Recalcule le forfait client (et le total serveur) après tout changement affectant le prix
   * (sièges, tronçon, bagages). Silencieux en cas d'échec réseau — l'affichage retombe alors
   * sur le total local (sans forfait) plutôt que de bloquer la réservation ; le montant
   * réellement facturé reste de toute façon recalculé côté serveur à la création.
   */
  private refreshPricePreview() {
    const seats = this.selectedSeatCount();
    if (seats === 0) {
      this.serviceFee.set(null);
      this.previewTotal.set(null);
      return;
    }
    const seq = ++this.previewSeq;
    let extra = Number(this.bookingForm.get('extraHoldBags')?.value ?? 0);
    if (Number.isNaN(extra) || extra < 0) extra = 0;

    this.bookingService
      .previewPrice({
        tripId: this.tripId,
        numberOfSeats: seats,
        boardingStopIndex: this.boardingIndex(),
        alightingStopIndex: this.alightingIndex(),
        extraHoldBags: extra,
        couponCode: this.appliedCoupon(),
      })
      .pipe(catchError(() => of(null)))
      .subscribe((preview) => {
        if (seq !== this.previewSeq) return;
        this.serviceFee.set(preview?.serviceFee ?? null);
        this.previewTotal.set(preview?.total ?? null);
      });
  }

  /**
   * Valide le code saisi côté serveur (même calcul que le preview/la création) et donne un
   * retour immédiat avant même de recalculer le total complet. `price` = sous-total sièges
   * actuel, cohérent avec ce que le backend applique réellement.
   */
  applyCoupon() {
    const code = this.couponInput().trim();
    if (!code || this.couponChecking()) return;
    const price = this.selectedSeatCount() * this.pricePerSeat();
    this.couponChecking.set(true);
    this.couponError.set(null);
    this.couponService.validate(code, price).subscribe({
      next: (res) => {
        this.couponChecking.set(false);
        this.appliedCoupon.set(code);
        this.couponDiscount.set({ originalPrice: res.originalPrice, finalPrice: res.finalPrice });
        this.refreshPricePreview();
      },
      error: (err) => {
        this.couponChecking.set(false);
        this.couponError.set(err?.error?.message || 'Coupon invalide ou expiré.');
        this.appliedCoupon.set(null);
        this.couponDiscount.set(null);
      },
    });
  }

  removeCoupon() {
    this.appliedCoupon.set(null);
    this.couponDiscount.set(null);
    this.couponError.set(null);
    this.couponInput.set('');
    this.refreshPricePreview();
  }

  luggageFeeAmount(): number {
    const trip = this.tripDetails();
    const extra = Number(this.bookingForm.get('extraHoldBags')?.value ?? 0);
    const unit = trip?.extraHoldBagPrice ?? 0;
    const e = Number.isNaN(extra) || extra < 0 ? 0 : extra;
    return e * unit;
  }

  /**
   * Total à payer : celui renvoyé par le serveur (avec forfait client) dès qu'il est
   * disponible. En attendant sa réponse (ou en cas d'échec réseau), retombe sur un total
   * local qui omet le forfait — annoncé comme tel n'importe où ailleurs, jamais utilisé pour
   * la facturation réelle (recalculée côté serveur à la création).
   */
  totalBookingPrice(): number {
    const preview = this.previewTotal();
    if (preview != null) return preview;
    const n = this.selectedSeatCount();
    return n * this.pricePerSeat() + this.luggageFeeAmount();
  }

  onSubmit() {
    if (!this.bookingForm.valid || !this.hasValidSegment() || this.isSubmitting()) return;

    const { selectedSeats, passengerNames } = this.bookingForm.value;
    const user = this.authService.currentUser();

    if (!user) {
      this.router.navigate(['/auth/login']);
      return;
    }

    const selections: SeatSelection[] = selectedSeats.map((seat: string, index: number) => ({
      passengerName: passengerNames[index],
      seatNumber: seat,
    }));

    let extra = Number(this.bookingForm.get('extraHoldBags')?.value ?? 0);
    if (Number.isNaN(extra) || extra < 0) extra = 0;
    const cap = this.maxExtraHoldForSelection();
    if (extra > cap) extra = cap;

    const payload: BookingRequest = {
      tripId: this.tripId,
      numberOfSeats: selectedSeats.length,
      selections,
      boardingStopIndex: this.boardingIndex(),
      alightingStopIndex: this.alightingIndex(),
      extraHoldBags: extra,
      couponCode: this.appliedCoupon(),
    };

    this.isSubmitting.set(true);
    this.bookingService.createBooking(payload).subscribe({
      next: (res: BookingResponse) => {
        this.isSubmitting.set(false);
        if (this.isCovoiturage()) {
          // Covoiturage : simple demande, pas de paiement immédiat — le conducteur a jusqu'à
          // 24h pour répondre ; paiement possible (30 min) depuis "Mes réservations" une fois
          // accepté. Jamais de redirection vers l'étape de paiement ici.
          this.notificationService.show(
            'Demande envoyée au conducteur ! Vous serez notifié dès sa réponse (sous 24h). Vous pourrez alors payer votre place depuis « Mes réservations ».',
            'success',
          );
          this.router.navigate(['/my-account/bookings']);
        } else {
          this.router.navigate(['/booking/confirmation', res.id]);
        }
      },
      error: (err) => {
        this.isSubmitting.set(false);
        this.notificationService.show(err.error?.message || 'Erreur de réservation.', 'error');
      },
    });
  }
}
