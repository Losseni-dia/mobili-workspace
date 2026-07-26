// lib/features/auth/providers/auth_provider.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobili/core/network/api_client.dart';
import 'package:mobili/core/services/analytics_service.dart';
import 'package:mobili/core/services/firebase_service.dart';

import '../../../core/models/auth_response.dart';
import '../../../core/models/mobili_error.dart';
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

  AuthState asError(String message, {Map<String, String>? fields}) => AuthState(
        status: AuthStatus.error,
        profile: profile,
        authResponse: authResponse,
        errorMessage: message,
        fieldErrors: fields,
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  late final AuthService _service;

@override
  Future<AuthState> build() async {
    _service = ref.read(authServiceProvider);
    try {
      final profile = await _service.getMe();
      // Session déjà active (pas de re-login) : on renvoie quand même le
      // token FCM au backend, sinon un utilisateur déjà connecté ne reçoit
      // jamais de push si son token n'avait pas encore été enregistré.
      unawaited(FirebaseService.sendTokenToBackend(ApiClient.instance.dio));
      return AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
      );
    } catch (_) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({required String login, required String password}) async {
    state = AsyncData(state.requireValue.asLoading());
    try {
      final authResponse =
          await _service.login(login: login, password: password);
      final profile = await _service.getMe();
      state = AsyncData(AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
        authResponse: authResponse,
      ));
      await FirebaseService.sendTokenToBackend(ApiClient.instance.dio);
      await AnalyticsService.logLogin();
      await AnalyticsService.setUserId('${profile.id}');
      await AnalyticsService.setUserRole(profile.roles.first);
      ref.read(showWelcomeProvider.notifier).state = true;
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
    await AnalyticsService.setUserId(null);
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }

Future<bool> register({
    required String firstname,
    required String lastname,
    required String email,
    required String login,
    required String password,
    required String phone,
    File? avatarFile,
  }) async {
    state = AsyncData(state.requireValue.asLoading());
    try {
      await _service.register(
        firstname: firstname,
        lastname: lastname,
        email: email,
        login: login,
        password: password,
        phone: phone,
        avatarFile: avatarFile,
      );
      state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
      await AnalyticsService.logRegister();
      ref.read(showRegisterSuccessProvider.notifier).state = true;
      return true;
    } on MobiliException catch (e) {
      // Le backend renvoie désormais directement les erreurs par champ
      // (validationErrors) pour MOB-003 (validation) et MOB-004 (doublon
      // email/login) — plus besoin de deviner via un contains() fragile.
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

  /// Re-fetch silencieux du profil (GET /auth/me) — utilisé quand on sait
  /// que le profil a pu changer côté serveur (ex: validation KYC covoiturage
  /// par un admin) sans que l'utilisateur ait besoin de se déconnecter /
  /// reconnecter pour voir le changement.
  Future<void> refreshProfile() async {
    if (!state.hasValue || !state.requireValue.isAuthenticated) return;
    try {
      final profile = await _service.getMe();
      setProfile(profile);
    } catch (_) {
      // Échec silencieux : on garde l'ancien profil affiché plutôt que de
      // casser l'écran sur une simple erreur réseau transitoire.
    }
  }
}

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentProfileProvider = Provider<ProfileDto?>((ref) {
  return ref.watch(authProvider).valueOrNull?.profile;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).valueOrNull?.isAuthenticated ?? false;
});

final showWelcomeProvider = StateProvider<bool>((ref) => false);
final showRegisterSuccessProvider = StateProvider<bool>((ref) => false);
