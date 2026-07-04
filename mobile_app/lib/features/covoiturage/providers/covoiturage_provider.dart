import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/mobili_error.dart';
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
    state = const CovoiturageApplyState(status: CovoiturageApplyStatus.submitting);
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
      state = const CovoiturageApplyState(status: CovoiturageApplyStatus.success);
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

final covoiturageApplyNotifierProvider =
    AutoDisposeNotifierProvider<CovoiturageApplyNotifier, CovoiturageApplyState>(
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
