// lib/features/auth/providers/auth_provider.dart

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilipro/core/network/api_client.dart';
import 'package:mobilipro/core/services/firebase_service.dart';
import 'package:mobilipro/features/notifications/providers/notification_provider.dart';

import '../../../core/models/auth_response.dart';
import '../../../core/models/mobili_error.dart'; // Pour choper MobiliException
import '../data/auth_service.dart';
import '../domain/models/profile_dto.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.authResponse,
    this.errorMessage,
    this.fieldErrors,
  });

  final AuthStatus status;
  final ProfileDto? profile;
  final AuthResponse? authResponse;
  final String? errorMessage;
  final Map<String, String>? fieldErrors;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasError => status == AuthStatus.error;

  AuthState copyWith({
    AuthStatus? status,
    ProfileDto? profile,
    AuthResponse? authResponse,
    String? errorMessage,
    Map<String, String>? fieldErrors,
  }) =>
      AuthState(
        status: status ?? this.status,
        profile: profile ?? this.profile,
        authResponse: authResponse ?? this.authResponse,
        errorMessage: errorMessage,
        fieldErrors: fieldErrors,
      );

  AuthState asLoading() => copyWith(
        status: AuthStatus.loading,
        errorMessage: null,
        fieldErrors: null,
      );

  AuthState asError(String message, {Map<String, String>? fields}) =>
      AuthState(
        status: AuthStatus.error,
        profile: profile,
        authResponse: authResponse,
        errorMessage: message,
        fieldErrors: fields,
      );
}

class AuthNotifier extends AutoDisposeAsyncNotifier<AuthState> {
  late final AuthService _service;

  @override
  Future<AuthState> build() async {
    _service = ref.read(authServiceProvider);
    try {
      final profile = await _service.getMe();
      return AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
      );
    } catch (_) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> refreshProfile() async {
    try {
      final profile = await _service.getMe();
      if (state.hasValue) {
        state = AsyncData(
          state.requireValue.copyWith(
            status: AuthStatus.authenticated,
            profile: profile,
          ),
        );
      }
    } catch (_) {
      // Ignore silencieusement — l'appelant peut retenter plus tard.
    }
  }

Future<bool> login({required String login, required String password}) async {
    if (state.valueOrNull?.isLoading == true) return false;
    state = AsyncData(state.requireValue.asLoading());
    try {
      final authResponse = await _service.login(
        login: login,
        password: password,
      );
      final profile = await _service.getMe();
      state = AsyncData(
        AuthState(
          status: AuthStatus.authenticated,
          profile: profile,
          authResponse: authResponse,
        ),
      );
    ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      final isStation = profile.roles.contains('STATION');
      await FirebaseService.sendTokenToBackend(
        ApiClient.instance.dio,
        isStation: isStation,
      );
      return true;
    } on MobiliException catch (e) {
      state = AsyncData(
        state.requireValue.asError(e.message, fields: e.validationErrors),
      );
      return false;
    } catch (e) {
      state = AsyncData(
        state.requireValue.asError('Une erreur inattendue est survenue.'),
      );
      return false;
    }
  }

Future<void> logout() async {
    state = AsyncData(state.requireValue.asLoading());
    await _service.logout();
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

Future<bool> register({
    required String firstname,
    required String lastname,
    required String email,
    required String login,
    required String password,
    File? avatarFile,
  }) async {
    if (state.valueOrNull?.isLoading == true) return false;
    state = AsyncData(state.requireValue.asLoading());
    try {
      final profile = await _service.register(
        firstname: firstname,
        lastname: lastname,
        email: email,
        login: login,
        password: password,
        avatarFile: avatarFile,
      );
state = AsyncData(
        AuthState(
          status: AuthStatus.authenticated,
          profile: profile,
          authResponse: null,
        ),
      );
      ;
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      await FirebaseService.sendTokenToBackend(ApiClient.instance.dio);
      return true;
    } on MobiliException catch (e) {
      state = AsyncData(
        state.requireValue.asError(e.message, fields: e.validationErrors),
      );
      return false;
    } catch (e) {
      state = AsyncData(
        state.requireValue.asError('Une erreur inattendue est survenue.'),
      );
      return false;
    }
  }

  /// Inscription "dirigeant société" — connecte automatiquement (le backend
  /// renvoie un token), contrairement à la candidature covoiturage.
Future<bool> registerCompany({
    required Map<String, dynamic> companyData,
    File? logoFile,
    required File kycFrontFile,
    required File kycBackFile,
  }) async {
    if (state.valueOrNull?.isLoading == true) return false;
    state = AsyncData(state.requireValue.asLoading());
    try {
      final authResponse = await _service.registerCompany(
        companyData: companyData,
        logoFile: logoFile,
        kycFrontFile: kycFrontFile,
        kycBackFile: kycBackFile,
      );
      final profile = await _service.getMe();
      state = AsyncData(AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
        authResponse: authResponse,
      ));
      return true;
    } on MobiliException catch (e) {
      state = AsyncData(
        state.requireValue.asError(e.message, fields: e.validationErrors),
      );
      return false;
    } catch (e) {
      state = AsyncData(
        state.requireValue.asError('Une erreur inattendue est survenue.'),
      );
      return false;
    }
  }

  /// Candidature conducteur covoiturage — le compte part désactivé (KYC
  /// PENDING) : pas de token renvoyé, pas de connexion automatique.
  /// Retourne `null` en cas de succès, ou un message d'erreur sinon.
  Future<String?> registerCarpoolChauffeur({
    required Map<String, dynamic> userData,
    required File idFront,
    required File idBack,
    required File driverPhoto,
    required File vehiclePhoto,
    required File licenseFront,
    required File licenseBack,
    required File greyCardFront,
    required File greyCardBack,
  }) async {
    try {
      await _service.registerCarpoolChauffeur(
        userData: userData,
        idFront: idFront,
        idBack: idBack,
        driverPhoto: driverPhoto,
        vehiclePhoto: vehiclePhoto,
        licenseFront: licenseFront,
        licenseBack: licenseBack,
        greyCardFront: greyCardFront,
        greyCardBack: greyCardBack,
      );
      return null;
    } on MobiliException catch (e) {
      return e.message;
    } catch (_) {
      return 'Une erreur inattendue est survenue.';
    }
  }

void setProfile(ProfileDto profile) {
    if (!state.hasValue) return;
    state = AsyncData(
      state.requireValue.copyWith(
        status: AuthStatus.authenticated,
        profile: profile,
      ),
    );
  }

  void clearError() {
    if (state.hasValue && state.requireValue.hasError) {
      state = AsyncData(
        state.requireValue.copyWith(status: AuthStatus.unauthenticated),
      );
    }
  }

  void clearFieldErrors() {
    if (!state.hasValue) return;
    state = AsyncData(state.requireValue.copyWith(fieldErrors: const {}));
  }
}

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authProvider = AutoDisposeAsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentProfileProvider = Provider.autoDispose<ProfileDto?>((ref) {
  return ref.watch(authProvider).valueOrNull?.profile;
});

final isAuthenticatedProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(authProvider).valueOrNull?.isAuthenticated ?? false;
});