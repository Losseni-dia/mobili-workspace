import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bookings/data/booking_service.dart';
import '../data/trip_service.dart';
import '../../bookings/domain/models/booking.dart';
import '../../bookings/domain/models/payment_request.dart';
import '../../bookings/domain/models/payment_verification_response.dart';
import '../domain/models/trip.dart';
import '../domain/models/trip_stop.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Services
// ─────────────────────────────────────────────────────────────────────────────

final tripServiceProvider = Provider<TripService>((_) => TripService());
final bookingServiceProvider =
    Provider<BookingService>((_) => BookingService());

// ─────────────────────────────────────────────────────────────────────────────
// Sentinel (pour copyWith nullable)
// ─────────────────────────────────────────────────────────────────────────────

const _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// Search params
// ─────────────────────────────────────────────────────────────────────────────

class TripSearchParams {
  const TripSearchParams({
    this.departure,
    this.arrival,
    this.date,
    this.transportType,
  });

  final String? departure;
  final String? arrival;
  final String? date;
  final String? transportType;

  bool get isEmpty => departure == null && arrival == null && date == null;

  TripSearchParams copyWith({
    Object? departure = _sentinel,
    Object? arrival = _sentinel,
    Object? date = _sentinel,
    Object? transportType = _sentinel,
  }) =>
      TripSearchParams(
        departure:
            departure == _sentinel ? this.departure : departure as String?,
        arrival: arrival == _sentinel ? this.arrival : arrival as String?,
        date: date == _sentinel ? this.date : date as String?,
        transportType: transportType == _sentinel
            ? this.transportType
            : transportType as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is TripSearchParams &&
      departure == other.departure &&
      arrival == other.arrival &&
      date == other.date &&
      transportType == other.transportType;

  @override
  int get hashCode => Object.hash(departure, arrival, date, transportType);
}

// Provider autocomplétion villes
// Autocomplétion villes
final citySearchProvider =
    FutureProvider.family<List<String>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  return ref.read(tripServiceProvider).fetchCities(query);
});


// ─────────────────────────────────────────────────────────────────────────────
// Trips list provider
// ─────────────────────────────────────────────────────────────────────────────

final tripSearchParamsProvider =
    StateProvider<TripSearchParams>((_) => const TripSearchParams());

final tripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final service = ref.read(tripServiceProvider);
  final params = ref.watch(tripSearchParamsProvider);

  final hasDeparture = params.departure != null && params.departure!.isNotEmpty;
  final hasArrival = params.arrival != null && params.arrival!.isNotEmpty;
  final hasDate = params.date != null && params.date!.isNotEmpty;

  // Dès qu'un champ est rempli (y compris la date seule), on délègue au
  // backend (comme le fait l'app Angular) : il matche par segment sur toute
  // la chaîne de villes (départ + étapes de moreInfo + arrivée), pas
  // seulement sur departureCity/arrivalCity au sens littéral. Un filtre
  // local ici manquerait les trajets où la ville cherchée n'est qu'une
  // étape intermédiaire — et getTrips() seul ignore totalement la date.
  if (hasDeparture || hasArrival || hasDate) {
    return service.searchTrips(
      departure: params.departure ?? '',
      arrival: params.arrival ?? '',
      date: params.date ?? '',
      transportType: params.transportType,
    );
  }

  return service.getTrips(transportType: params.transportType);
});

// ─────────────────────────────────────────────────────────────────────────────
// Trip detail + stops
// ─────────────────────────────────────────────────────────────────────────────

final tripDetailProvider =
    FutureProvider.autoDispose.family<Trip, int>((ref, id) {
  return ref.read(tripServiceProvider).getTripById(id);
});

final tripStopsProvider =
    FutureProvider.autoDispose.family<List<TripStop>, int>((ref, tripId) {
  return ref.read(tripServiceProvider).getTripStops(tripId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Occupied seats (real-time)
// ─────────────────────────────────────────────────────────────────────────────

class OccupiedSeatsParams {
  const OccupiedSeatsParams({
    required this.tripId,
    this.boardingStopIndex,
    this.alightingStopIndex,
  });

  final int tripId;
  final int? boardingStopIndex;
  final int? alightingStopIndex;

  @override
  bool operator ==(Object other) =>
      other is OccupiedSeatsParams &&
      tripId == other.tripId &&
      boardingStopIndex == other.boardingStopIndex &&
      alightingStopIndex == other.alightingStopIndex;

  @override
  int get hashCode =>
      Object.hash(tripId, boardingStopIndex, alightingStopIndex);
}

final occupiedSeatsProvider = FutureProvider.autoDispose
    .family<List<int>, OccupiedSeatsParams>((ref, params) {
  return ref.read(tripServiceProvider).getOccupiedSeats(
        params.tripId,
        boardingStopIndex: params.boardingStopIndex,
        alightingStopIndex: params.alightingStopIndex,
      );
});

// ─────────────────────────────────────────────────────────────────────────────
// Booking state machine
// ─────────────────────────────────────────────────────────────────────────────

enum BookingStep { idle, creating, awaitingPayment, verifying, done, error }

class BookingState {
  const BookingState({
    this.step = BookingStep.idle,
    this.booking,
    this.paymentUrl,
    this.result,
    this.errorMessage,
  });

  final BookingStep step;
  final Booking? booking;
  final String? paymentUrl;
  final PaymentVerificationResponse? result;
  final String? errorMessage;

  bool get isLoading =>
      step == BookingStep.creating || step == BookingStep.verifying;

  BookingState copyWith({
    BookingStep? step,
    Booking? booking,
    String? paymentUrl,
    PaymentVerificationResponse? result,
    String? errorMessage,
  }) =>
      BookingState(
        step: step ?? this.step,
        booking: booking ?? this.booking,
        paymentUrl: paymentUrl ?? this.paymentUrl,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class BookingNotifier extends StateNotifier<BookingState> {
  BookingNotifier(this._service) : super(const BookingState());

  final BookingService _service;

  /// [customerEmail] : reçu de paiement Stripe/FedaPay — optionnel, transmis
  /// tel quel au backend. [provider] : 'FEDAPAY' (Mobile Money) ou 'STRIPE'
  /// (carte bancaire), choisi par l'utilisateur sur l'écran de réservation.
  Future<void> createAndPay(
    CreateBookingRequest request, {
    required String provider,
    String? customerEmail,
  }) async {
    state = state.copyWith(step: BookingStep.creating);
    try {
      final booking = await _service.createBooking(request);
      final response = await _service.checkout(
        booking.id,
        PaymentRequest(provider: provider, customerEmail: customerEmail),
      );
      state = state.copyWith(
        step: BookingStep.awaitingPayment,
        booking: booking,
        paymentUrl: response.paymentUrl,
      );
    } catch (e) {
      state = state.copyWith(
        step: BookingStep.error,
        errorMessage: _extractMessage(e),
      );
    }
  }

Future<void> verifyAfterReturn() async {
    final bookingId = state.booking?.id;
    if (bookingId == null) return;

    state = state.copyWith(step: BookingStep.verifying);
    try {
      final result = await _service.verifyPayment(bookingId);
      print('🔍 verifyPayment result: ${result.confirmed} / ${result.status}');
      if (result.confirmed) {
        state = state.copyWith(step: BookingStep.done, result: result);
        return;
      }
      final polled = await _service.pollUntilConfirmed(
        bookingId,
        maxAttempts: 5,
        interval: const Duration(seconds: 2),
      );
      print(
          '🔍 pollUntilConfirmed result: ${polled.confirmed} / ${polled.status}');
      state = state.copyWith(
        step: polled.confirmed ? BookingStep.done : BookingStep.error,
        result: polled,
        errorMessage: polled.confirmed ? null : 'Paiement non confirmé.',
      );
    } catch (e) {
      print('🔍 verifyAfterReturn error: $e');
      state = state.copyWith(
        step: BookingStep.error,
        errorMessage: _extractMessage(e),
      );
    }
  }
  
  void reset() => state = const BookingState();

  String _extractMessage(Object e) {
    if (e is Exception) return e.toString();
    return 'Une erreur est survenue';
  }
}

final bookingNotifierProvider =
    StateNotifierProvider.autoDispose<BookingNotifier, BookingState>((ref) {
  return BookingNotifier(ref.read(bookingServiceProvider));
});


 
// ─────────────────────────────────────────────────────────────────────────────
// Covoiturage : demande de réservation (passager)
// ─────────────────────────────────────────────────────────────────────────────

enum CovoiturageRequestStep { idle, sending, sent, error }

class CovoiturageRequestState {
  const CovoiturageRequestState({
    this.step = CovoiturageRequestStep.idle,
    this.booking,
    this.errorMessage,
  });

  final CovoiturageRequestStep step;
  final Booking? booking;
  final String? errorMessage;

  bool get isLoading => step == CovoiturageRequestStep.sending;

  CovoiturageRequestState copyWith({
    CovoiturageRequestStep? step,
    Booking? booking,
    String? errorMessage,
  }) =>
      CovoiturageRequestState(
        step: step ?? this.step,
        booking: booking ?? this.booking,
        errorMessage: errorMessage,
      );
}

class CovoiturageRequestNotifier
    extends StateNotifier<CovoiturageRequestState> {
  CovoiturageRequestNotifier(this._service)
      : super(const CovoiturageRequestState());

  final BookingService _service;

  Future<void> sendRequest(CreateBookingRequest request) async {
    state = state.copyWith(step: CovoiturageRequestStep.sending);
    try {
      final booking = await _service.createCovoiturageRequest(request);
      state = state.copyWith(
        step: CovoiturageRequestStep.sent,
        booking: booking,
      );
    } catch (e) {
      state = state.copyWith(
        step: CovoiturageRequestStep.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const CovoiturageRequestState();
}

final covoiturageRequestNotifierProvider = StateNotifierProvider.autoDispose<
    CovoiturageRequestNotifier, CovoiturageRequestState>((ref) {
  return CovoiturageRequestNotifier(ref.read(bookingServiceProvider));
});

// ─────────────────────────────────────────────────────────────────────────────
// Covoiturage : demandes en attente pour un trajet (chauffeur)
// ─────────────────────────────────────────────────────────────────────────────

final pendingCovoiturageRequestsProvider =
    FutureProvider.autoDispose.family<List<Booking>, int>((ref, tripId) async {
  return ref.read(bookingServiceProvider).getPendingCovoiturageRequests(tripId);
});

enum CovoiturageDecisionStep { idle, submitting, done, error }

class CovoiturageDecisionState {
  const CovoiturageDecisionState({
    this.step = CovoiturageDecisionStep.idle,
    this.errorMessage,
  });

  final CovoiturageDecisionStep step;
  final String? errorMessage;

  bool get isLoading => step == CovoiturageDecisionStep.submitting;

  CovoiturageDecisionState copyWith({
    CovoiturageDecisionStep? step,
    String? errorMessage,
  }) =>
      CovoiturageDecisionState(
        step: step ?? this.step,
        errorMessage: errorMessage,
      );
}

class CovoiturageDecisionNotifier
    extends StateNotifier<CovoiturageDecisionState> {
  CovoiturageDecisionNotifier(this._service)
      : super(const CovoiturageDecisionState());

  final BookingService _service;

  Future<bool> accept(int tripId, int bookingId) async {
    state = state.copyWith(step: CovoiturageDecisionStep.submitting);
    try {
      await _service.acceptCovoiturageRequest(tripId, bookingId);
      state = state.copyWith(step: CovoiturageDecisionStep.done);
      return true;
    } catch (e) {
      state = state.copyWith(
        step: CovoiturageDecisionStep.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> reject(int tripId, int bookingId) async {
    state = state.copyWith(step: CovoiturageDecisionStep.submitting);
    try {
      await _service.rejectCovoiturageRequest(tripId, bookingId);
      state = state.copyWith(step: CovoiturageDecisionStep.done);
      return true;
    } catch (e) {
      state = state.copyWith(
        step: CovoiturageDecisionStep.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

final covoiturageDecisionNotifierProvider = StateNotifierProvider
    <CovoiturageDecisionNotifier, CovoiturageDecisionState>((ref) {
  return CovoiturageDecisionNotifier(ref.read(bookingServiceProvider));
});