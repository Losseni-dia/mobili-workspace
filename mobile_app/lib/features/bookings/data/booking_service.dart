import 'dart:async';

import 'package:dio/dio.dart';
import 'package:mobili/features/bookings/domain/models/booking_detail.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/booking.dart';
import '../domain/models/ticket.dart';

class BookingService {
  BookingService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

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

  Future<List<BookingDetail>> getBookingDetailsForUser(int userId) async {
    final response = await _dio.get<List<dynamic>>('/bookings/user/$userId');
    if (response.data == null) return [];
    return (response.data as List<dynamic>)
        .map((e) => BookingDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Booking> getBookingById(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/bookings/$id');
    return Booking.fromJson(response.data!);
  }

  Future<List<Booking>> getBookingsForUser(int userId) async {
    final response = await _dio.get<List<dynamic>>('/bookings/user/$userId');
    return _parseList(response.data);
  }

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

  Future<PaymentResult> verifyPayment(int bookingId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/verify/$bookingId',
    );
    return PaymentResult.fromJson(response.data!);
  }

  Future<PaymentResult> pollUntilConfirmed(
    int bookingId, {
    int maxAttempts = 5,
    Duration interval = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final result = await verifyPayment(bookingId);
      if (result.success) return result;
      if (i < maxAttempts - 1) await Future<void>.delayed(interval);
    }
    return verifyPayment(bookingId);
  }

  List<Booking> _parseList(dynamic data) {
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SeatSelection
// ─────────────────────────────────────────────────────────────────────────────

class SeatSelection {
  const SeatSelection({
    required this.seatNumber,
    required this.passengerName,
  });
  final String seatNumber;
  final String passengerName;

  Map<String, dynamic> toJson() => {
        'seatNumber': seatNumber,
        'passengerName': passengerName,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// CreateBookingRequest
// ─────────────────────────────────────────────────────────────────────────────

class CreateBookingRequest {
  const CreateBookingRequest({
    required this.tripId,
    required this.userId,
    required this.numberOfSeats,
    required this.selections,
    required this.boardingStopIndex,
    required this.alightingStopIndex,
    this.extraHoldBags = 0,
  });

  final int tripId;
  final int userId;
  final int numberOfSeats;
  final List<SeatSelection> selections;
  final int boardingStopIndex;
  final int alightingStopIndex;
  final int extraHoldBags;

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'userId': userId,
        'numberOfSeats': numberOfSeats,
        'selections': selections.map((s) => s.toJson()).toList(),
        'boardingStopIndex': boardingStopIndex,
        'alightingStopIndex': alightingStopIndex,
        'extraHoldBags': extraHoldBags,
      };
}
