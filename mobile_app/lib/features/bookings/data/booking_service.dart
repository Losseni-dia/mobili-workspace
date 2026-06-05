import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/booking.dart';
import '../domain/models/ticket.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BookingService
// ─────────────────────────────────────────────────────────────────────────────

class BookingService {
  BookingService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  // ── Create booking ─────────────────────────────────────────────────────────

  Future<Booking> createBooking(CreateBookingRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/bookings',
      data: request.toJson(),
    );
    return Booking.fromJson(response.data!);
  }

 Future<List<Ticket>> getTicketsForUser(int userId) async {
    final response = await _dio.get<List<dynamic>>('/tickets/user/$userId');
    if (response.data == null) return [];
    return (response.data as List<dynamic>)
        .map((e) => Ticket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Read bookings ──────────────────────────────────────────────────────────

  Future<Booking> getBookingById(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/bookings/$id');
    return Booking.fromJson(response.data!);
  }

  Future<List<Booking>> getBookingsForUser(int userId) async {
    final response =
        await _dio.get<List<dynamic>>('/bookings/user/$userId');
    return _parseList(response.data);
  }

  // ── Payment flow ───────────────────────────────────────────────────────────

  /// Step 1 — creates a FedaPay session and returns the redirect URL.
  Future<String> checkout(int bookingId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/checkout/$bookingId',
    );
    final url = response.data?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('checkout: missing url in response');
    }
    return url;
  }

  /// Step 2 — verify payment status after user returns from FedaPay.
  ///
  /// If [success] is false and [status] is PENDING, callers should poll
  /// via [pollUntilConfirmed].
  Future<PaymentResult> verifyPayment(int bookingId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/verify/$bookingId',
    );
    return PaymentResult.fromJson(response.data!);
  }

  /// Polls verify every [interval] until success or [maxAttempts] reached.
  Future<PaymentResult> pollUntilConfirmed(
    int bookingId, {
    int maxAttempts = 10,
    Duration interval = const Duration(seconds: 3),
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final result = await verifyPayment(bookingId);
      if (result.success) return result;
      if (i < maxAttempts - 1) await Future<void>.delayed(interval);
    }
    // Return the last known result (PENDING / failed)
    return verifyPayment(bookingId);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<Booking> _parseList(dynamic data) {
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CreateBookingRequest
// ─────────────────────────────────────────────────────────────────────────────

class CreateBookingRequest {
  const CreateBookingRequest({
    required this.tripId,
    required this.seatNumber,
    required this.boardingStopIndex,
    required this.alightingStopIndex,
  });

  final int tripId;
  final int seatNumber;
  final int boardingStopIndex;
  final int alightingStopIndex;

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'seatNumber': seatNumber,
        'boardingStopIndex': boardingStopIndex,
        'alightingStopIndex': alightingStopIndex,
      };
}
