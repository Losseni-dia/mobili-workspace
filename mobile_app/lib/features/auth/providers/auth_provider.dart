// lib/features/auth/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      final authResponse = await _service.login(login: login, password: password);
      final profile = await _service.getMe();
      state = AsyncData(AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
        authResponse: authResponse,
      ));
      return true;
    } on MobiliException catch (e) {
      state = AsyncData(
        state.requireValue.asError(
          e.message, // CORRECTION : c'est .message dans MobiliException
          fields: e.validationErrors, // CORRECTION : c'est .validationErrors
        ),
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
  }

  Future<bool> register({
    required String firstname,
    required String lastname,
    required String email,
    required String login,
    required String password,
  }) async {
    state = AsyncData(state.requireValue.asLoading());
    try {
      final profile = await _service.register(
        firstname: firstname,
        lastname: lastname,
        email: email,
        login: login,
        password: password,
      );
      state = AsyncData(AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
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