import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobili/features/bookings/domain/models/booking.dart';

import '../../../core/models/mobili_error.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trips/domain/models/trip.dart';
import '../data/covoiturage_service.dart';

final covoiturageServiceProvider =
    Provider<CovoiturageService>((_) => CovoiturageService());

// ─────────────────────────────────────────────────────────────────────────────
// Mes trajets covoiturage (conducteur)
// ─────────────────────────────────────────────────────────────────────────────

final myCovoiturageTripsProvider = FutureProvider<List<Trip>>((ref) async {
  return ref.read(covoiturageServiceProvider).getMyTrips();
});

// ─────────────────────────────────────────────────────────────────────────────
// Stats dashboard covoiturage (trajets actifs, réservations, revenus, résa
// récentes) — même structure que le dashboard partenaire transport public.
// ─────────────────────────────────────────────────────────────────────────────

class PartnerDashboardStats {
  const PartnerDashboardStats({
    required this.activeTripsCount,
    required this.totalBookingsCount,
    required this.totalRevenue,
    required this.revenueOnline,
    required this.revenueOffline,
    required this.recentBookings,
  });

  final int activeTripsCount;
  final int totalBookingsCount;
  final double totalRevenue;
  final double revenueOnline;
  final double revenueOffline;
  final List<PartnerRecentBooking> recentBookings;

  factory PartnerDashboardStats.fromJson(Map<String, dynamic> json) =>
      PartnerDashboardStats(
        activeTripsCount: (json['activeTripsCount'] as num?)?.toInt() ?? 0,
        totalBookingsCount: (json['totalBookingsCount'] as num?)?.toInt() ?? 0,
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
        revenueOnline: (json['revenueOnline'] as num?)?.toDouble() ?? 0.0,
        revenueOffline: (json['revenueOffline'] as num?)?.toDouble() ?? 0.0,
        recentBookings: (json['recentBookings'] as List<dynamic>? ?? [])
            .map(
                (e) => PartnerRecentBooking.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PartnerRecentBooking {
  const PartnerRecentBooking({
    required this.id,
    required this.customerName,
    required this.tripRoute,
    required this.date,
    required this.amount,
    required this.status,
    required this.passengerNames,
    required this.seatNumbers,
  });

  final int id;
  final String customerName;
  final String tripRoute;
  final DateTime date;
  final double amount;
  final String status;
  final List<String> passengerNames;
  final List<String> seatNumbers;

  String get displayName =>
      passengerNames.isNotEmpty ? passengerNames.join(', ') : customerName;

  String get formattedAmount => '${amount.toStringAsFixed(0)} FCFA';

  factory PartnerRecentBooking.fromJson(Map<String, dynamic> json) =>
      PartnerRecentBooking(
        id: json['id'] as int,
        customerName: json['customerName'] as String? ?? '',
        tripRoute: json['tripRoute'] as String? ?? '',
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? '',
        passengerNames: (json['passengerNames'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        seatNumbers: (json['seatNumbers'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}

final covoiturageDashboardStatsProvider =
    FutureProvider.autoDispose<PartnerDashboardStats>((ref) async {
  final dio = ApiClient.instance.dio;
  final response =
      await dio.get<Map<String, dynamic>>('/covoiturage/trips/dashboard/stats');
  return PartnerDashboardStats.fromJson(response.data!);
});

// ─────────────────────────────────────────────────────────────────────────────
// Compteur de demandes en attente par trajet (badge sur "Tous mes trajets")
// ─────────────────────────────────────────────────────────────────────────────

final pendingRequestsCountByTripProvider =
    FutureProvider.autoDispose<Map<int, int>>((ref) async {
  final dio = ApiClient.instance.dio;
  final response = await dio
      .get<Map<String, dynamic>>('/covoiturage/trips/pending-requests-count');
  final data = response.data ?? {};
  return data.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
});

// ─────────────────────────────────────────────────────────────────────────────
// Candidature conducteur (compte voyageur existant déjà connecté)
// ─────────────────────────────────────────────────────────────────────────────

enum CovoiturageApplyStatus { idle, submitting, success, error }

class CovoiturageApplyState {
  const CovoiturageApplyState({
    this.status = CovoiturageApplyStatus.idle,
    this.errorMessage,
  });

  final CovoiturageApplyStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == CovoiturageApplyStatus.submitting;
}

final allPendingCovoiturageRequestsProvider =
    FutureProvider.autoDispose<List<Booking>>((ref) async {
  final dio = ApiClient.instance.dio;
  final response =
      await dio.get<List<dynamic>>('/covoiturage/trips/pending-requests');
  return (response.data ?? [])
      .map((e) => Booking.fromJson(e as Map<String, dynamic>))
      .toList();
});

class CovoiturageApplyNotifier
    extends AutoDisposeNotifier<CovoiturageApplyState> {
  @override
  CovoiturageApplyState build() => const CovoiturageApplyState();

  Future<bool> submit({
    required DateTime idValidUntil,
    required String vehicleBrand,
    required String vehiclePlate,
    required String vehicleColor,
    required String greyCardNumber,
    required File idFront,
    required File idBack,
    required File driverPhoto,
    required File vehiclePhoto,
  }) async {
    state =
        const CovoiturageApplyState(status: CovoiturageApplyStatus.submitting);
    try {
      final profile = await ref.read(covoiturageServiceProvider).applyAsDriver(
            idValidUntil: idValidUntil,
            vehicleBrand: vehicleBrand,
            vehiclePlate: vehiclePlate,
            vehicleColor: vehicleColor,
            greyCardNumber: greyCardNumber,
            idFront: idFront,
            idBack: idBack,
            driverPhoto: driverPhoto,
            vehiclePhoto: vehiclePhoto,
          );
      ref.read(authProvider.notifier).setProfile(profile);
      state =
          const CovoiturageApplyState(status: CovoiturageApplyStatus.success);
      return true;
    } on MobiliException catch (e) {
      state = CovoiturageApplyState(
        status: CovoiturageApplyStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (_) {
      state = const CovoiturageApplyState(
        status: CovoiturageApplyStatus.error,
        errorMessage: 'Une erreur inattendue est survenue.',
      );
      return false;
    }
  }
}

final covoiturageApplyNotifierProvider = AutoDisposeNotifierProvider<
    CovoiturageApplyNotifier, CovoiturageApplyState>(
  CovoiturageApplyNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// Mise à jour du profil conducteur (véhicule + photos)
// ─────────────────────────────────────────────────────────────────────────────

enum CovoiturageProfileSaveStatus { idle, saving, success, error }

class CovoiturageProfileSaveState {
  const CovoiturageProfileSaveState({
    this.status = CovoiturageProfileSaveStatus.idle,
    this.errorMessage,
  });

  final CovoiturageProfileSaveStatus status;
  final String? errorMessage;

  bool get isSaving => status == CovoiturageProfileSaveStatus.saving;
}

class CovoiturageProfileNotifier
    extends AutoDisposeNotifier<CovoiturageProfileSaveState> {
  @override
  CovoiturageProfileSaveState build() => const CovoiturageProfileSaveState();

  Future<bool> save({
    required String vehicleBrand,
    required String vehiclePlate,
    required String vehicleColor,
    required String greyCardNumber,
    File? driverPhoto,
    File? vehiclePhoto,
  }) async {
    state = const CovoiturageProfileSaveState(
      status: CovoiturageProfileSaveStatus.saving,
    );
    try {
      final updated = await ref.read(covoiturageServiceProvider).updateProfile(
            vehicleBrand: vehicleBrand,
            vehiclePlate: vehiclePlate,
            vehicleColor: vehicleColor,
            greyCardNumber: greyCardNumber,
            driverPhoto: driverPhoto,
            vehiclePhoto: vehiclePhoto,
          );
      // Le profil renvoyé par /covoiturage/profile est la source la plus
      // fraîche : on le propage dans authProvider pour que tout l'app (badge
      // KYC, etc.) reflète immédiatement le changement.
      ref.read(authProvider.notifier).setProfile(updated);
      state = const CovoiturageProfileSaveState(
        status: CovoiturageProfileSaveStatus.success,
      );
      return true;
    } on MobiliException catch (e) {
      state = CovoiturageProfileSaveState(
        status: CovoiturageProfileSaveStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (_) {
      state = const CovoiturageProfileSaveState(
        status: CovoiturageProfileSaveStatus.error,
        errorMessage: 'Une erreur inattendue est survenue.',
      );
      return false;
    }
  }
}

final covoiturageProfileNotifierProvider = AutoDisposeNotifierProvider<
    CovoiturageProfileNotifier, CovoiturageProfileSaveState>(
  CovoiturageProfileNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// Création / édition de trajet
// ─────────────────────────────────────────────────────────────────────────────

enum CovoiturageTripSaveStatus { idle, saving, success, error }

class CovoiturageTripSaveState {
  const CovoiturageTripSaveState({
    this.status = CovoiturageTripSaveStatus.idle,
    this.errorMessage,
  });

  final CovoiturageTripSaveStatus status;
  final String? errorMessage;

  bool get isSaving => status == CovoiturageTripSaveStatus.saving;
}

class CovoiturageTripNotifier
    extends AutoDisposeNotifier<CovoiturageTripSaveState> {
  @override
  CovoiturageTripSaveState build() => const CovoiturageTripSaveState();

  Future<bool> create({
    required Map<String, dynamic> tripData,
    File? vehicleImage,
  }) async {
    state = const CovoiturageTripSaveState(
      status: CovoiturageTripSaveStatus.saving,
    );
    try {
      await ref.read(covoiturageServiceProvider).createTrip(
            tripData: tripData,
            vehicleImage: vehicleImage,
          );
      ref.invalidate(myCovoiturageTripsProvider);
      state = const CovoiturageTripSaveState(
        status: CovoiturageTripSaveStatus.success,
      );
      return true;
    } on MobiliException catch (e) {
      state = CovoiturageTripSaveState(
        status: CovoiturageTripSaveStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (_) {
      state = const CovoiturageTripSaveState(
        status: CovoiturageTripSaveStatus.error,
        errorMessage: 'Une erreur inattendue est survenue.',
      );
      return false;
    }
  }

  Future<bool> update({
    required int id,
    required Map<String, dynamic> tripData,
    File? vehicleImage,
  }) async {
    state = const CovoiturageTripSaveState(
      status: CovoiturageTripSaveStatus.saving,
    );
    try {
      await ref.read(covoiturageServiceProvider).updateTrip(
            id: id,
            tripData: tripData,
            vehicleImage: vehicleImage,
          );
      ref.invalidate(myCovoiturageTripsProvider);
      state = const CovoiturageTripSaveState(
        status: CovoiturageTripSaveStatus.success,
      );
      return true;
    } on MobiliException catch (e) {
      state = CovoiturageTripSaveState(
        status: CovoiturageTripSaveStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (_) {
      state = const CovoiturageTripSaveState(
        status: CovoiturageTripSaveStatus.error,
        errorMessage: 'Une erreur inattendue est survenue.',
      );
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await ref.read(covoiturageServiceProvider).deleteTrip(id);
      ref.invalidate(myCovoiturageTripsProvider);
      return true;
    } on MobiliException catch (e) {
      state = CovoiturageTripSaveState(
        status: CovoiturageTripSaveStatus.error,
        errorMessage: e.message,
      );
      return false;
    }
  }
}

final covoiturageTripNotifierProvider = AutoDisposeNotifierProvider<
    CovoiturageTripNotifier, CovoiturageTripSaveState>(
  CovoiturageTripNotifier.new,
);
