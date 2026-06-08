import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/trip.dart';
import '../domain/models/trip_stop.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hive box names
// ─────────────────────────────────────────────────────────────────────────────

const _kTripsBox = 'trips_cache';
const _kTripsListKey = 'trips_list';
const _kTripDetailPrefix = 'trip_detail_';
const _kTripStopsPrefix = 'trip_stops_';
const _kCacheTtlMs = 5 * 60 * 1000; // 5 min

// ─────────────────────────────────────────────────────────────────────────────
// TripService
// ─────────────────────────────────────────────────────────────────────────────

class TripService {
  TripService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<Box> get _box async => Hive.openBox(_kTripsBox);

  // ── List / search ──────────────────────────────────────────────────────────

  /// Returns upcoming trips. Uses Hive cache (5 min TTL) for offline-first UX.
  Future<List<Trip>> getTrips({String? transportType}) async {
    final cacheKey =
        transportType != null ? '${_kTripsListKey}_$transportType' : _kTripsListKey;

    // Try cache first
    final cached = await _getCached<List<Trip>>(
      cacheKey,
      (raw) => (raw as List).map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList(),
    );
    if (cached != null) return cached;

    // Network
    final queryParams = <String, dynamic>{
      if (transportType != null) 'transportType': transportType,
    };
    final response = await _dio.get<List<dynamic>>(
      '/trips',
      queryParameters: queryParams,
    );
    final trips = _parseList(response.data);
    await _putCached(cacheKey, trips.map((t) => t.toJson()).toList());
    return trips;
  }

  /// Search trips — no cache (query-specific, always fresh).
  Future<List<Trip>> searchTrips({
    required String departure,
    required String arrival,
    required String date, // YYYY-MM-DD
    String? transportType,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/trips/search',
      queryParameters: {
        'departure': departure,
        'arrival': arrival,
        'date': date,
        if (transportType != null) 'transportType': transportType,
      },
    );
    return _parseList(response.data);
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  Future<Trip> getTripById(int id) async {
    final cacheKey = '$_kTripDetailPrefix$id';

    final cached = await _getCached<Trip>(
      cacheKey,
      (raw) => Trip.fromJson(raw as Map<String, dynamic>),
    );
    if (cached != null) return cached;

    final response = await _dio.get<Map<String, dynamic>>('/trips/$id');
    final trip = Trip.fromJson(response.data!);
    await _putCached(cacheKey, trip.toJson());
    return trip;
  }

  Future<List<TripStop>> getTripStops(int tripId) async {
    final cacheKey = '$_kTripStopsPrefix$tripId';

    final cached = await _getCached<List<TripStop>>(
      cacheKey,
      (raw) =>
          (raw as List).map((e) => TripStop.fromJson(e as Map<String, dynamic>)).toList(),
    );
    if (cached != null) return cached;

    final response = await _dio.get<List<dynamic>>('/trips/$tripId/stops');
    final stops = (response.data as List<dynamic>)
        .map((e) => TripStop.fromJson(e as Map<String, dynamic>))
        .toList();
    await _putCached(cacheKey, stops.map((s) => s.toJson()).toList());
    return stops;
  }

  // ── Occupied seats (real-time, no cache) ──────────────────────────────────

  Future<List<int>> getOccupiedSeats(
    int tripId, {
    int? boardingStopIndex,
    int? alightingStopIndex,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/bookings/trips/$tripId/occupied-seats',
      queryParameters: {
        if (boardingStopIndex != null) 'boardingStopIndex': boardingStopIndex,
        if (alightingStopIndex != null) 'alightingStopIndex': alightingStopIndex,
      },
    );
   return (response.data as List<dynamic>)
        .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
        .where((e) => e > 0)
        .toList();
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────

  Future<T?> _getCached<T>(
    String key,
    T Function(dynamic raw) fromRaw,
  ) async {
    try {
      final box = await _box;
      final entry = box.get(key) as Map?;
      if (entry == null) return null;

      final expiresAt = entry['expiresAt'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        await box.delete(key);
        return null;
      }

      final raw = jsonDecode(entry['data'] as String);
      return fromRaw(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _putCached(String key, dynamic value) async {
    final box = await _box;
    await box.put(key, {
      'data': jsonEncode(value),
      'expiresAt':
          DateTime.now().millisecondsSinceEpoch + _kCacheTtlMs,
    });
  }

  Future<void> invalidateCache() async {
    final box = await _box;
    await box.clear();
  }

  // ── Parse helper ───────────────────────────────────────────────────────────

  List<Trip> _parseList(dynamic data) {
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => Trip.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
