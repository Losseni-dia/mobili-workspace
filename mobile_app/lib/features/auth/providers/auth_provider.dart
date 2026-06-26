// lib/features/auth/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobili/core/network/api_client.dart';
import 'package:mobili/core/services/analytics_service.dart';
import 'package:mobili/core/services/firebase_service.dart';
import 'dart:io';
import '../../../core/models/mobili_error.dart'; // Pour choper MobiliException
import '../data/auth_service.dart';
import '../domain/models/profile_dto.dart';
import '../../../core/models/auth_response.dart';

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
// Envoyer token FCM au backend après login
      await FirebaseService.sendTokenToBackend(ApiClient.instance.dio);
      await AnalyticsService.logLogin();
      await AnalyticsService.setUserId('${profile.id}');
      await AnalyticsService.setUserRole(profile.roles.first);
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
      final profile = await _service.register(
        firstname: firstname,
        lastname: lastname,
        email: email,
        login: login,
        password: password,
        phone: phone,
        avatarFile: avatarFile,
      );
     state = AsyncData(AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
      ));
      await AnalyticsService.logRegister();
      await AnalyticsService.setUserId('${profile.id}');
      await AnalyticsService.setUserRole(profile.roles.first);
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

  /// Remplace le profil en cache (ex: après une mise à jour partielle comme
  /// `/covoiturage/profile`) sans repasser par `getMe()`.
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