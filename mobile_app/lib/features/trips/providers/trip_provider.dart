import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bookings/data/booking_service.dart';
import '../data/trip_service.dart';
import '../../bookings/domain/models/booking.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// Trips list provider
// ─────────────────────────────────────────────────────────────────────────────

final tripSearchParamsProvider =
    StateProvider<TripSearchParams>((_) => const TripSearchParams());

final tripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  final service = ref.read(tripServiceProvider);
  final params = ref.watch(tripSearchParamsProvider);

  List<Trip> trips;

  // Recherche backend seulement si départ ET arrivée sont remplis
  if (params.departure != null &&
      params.departure!.isNotEmpty &&
      params.arrival != null &&
      params.arrival!.isNotEmpty) {
    trips = await service.searchTrips(
      departure: params.departure!,
      arrival: params.arrival!,
      date: params.date ?? '',
      transportType: params.transportType,
    );
  } else {
    // Sinon tous les trajets
    trips = await service.getTrips(transportType: params.transportType);
  }

  // Filtre local côté Flutter si un seul champ est rempli
  if (params.departure != null && params.departure!.isNotEmpty) {
    final dep = params.departure!.toLowerCase();
    trips = trips
        .where((t) => t.departureCity.toLowerCase().contains(dep))
        .toList();
  }
  if (params.arrival != null && params.arrival!.isNotEmpty) {
    final arr = params.arrival!.toLowerCase();
    trips =
        trips.where((t) => t.arrivalCity.toLowerCase().contains(arr)).toList();
  }

  return trips;
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
  final PaymentResult? result;
  final String? errorMessage;

  bool get isLoading =>
      step == BookingStep.creating || step == BookingStep.verifying;

  BookingState copyWith({
    BookingStep? step,
    Booking? booking,
    String? paymentUrl,
    PaymentResult? result,
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

  Future<void> createAndPay(CreateBookingRequest request) async {
    state = state.copyWith(step: BookingStep.creating);
    try {
      final booking = await _service.createBooking(request);
      final url = await _service.checkout(booking.id);
      state = state.copyWith(
        step: BookingStep.awaitingPayment,
        booking: booking,
        paymentUrl: url,
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
      final result = await _service.pollUntilConfirmed(bookingId);
      state = state.copyWith(
        step: BookingStep.done,
        result: result,
      );
    } catch (e) {
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
