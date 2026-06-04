import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/models/auth_response.dart';
import '../../../core/models/mobili_error.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/profile_dto.dart';

/// Data-layer service for all authentication endpoints.
///
/// Every method either returns a typed result or throws a [MobiliException].
/// Callers (Riverpod Notifiers / Repositories) should catch [MobiliException]
/// and surface [MobiliException.message] to the user.
class AuthService {
  AuthService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  // ─────────────────────────────────────────────────────────────────────────
  // POST /auth/login
  // ─────────────────────────────────────────────────────────────────────────

  /// Authenticates with [login] + [password].
  ///
  /// On success:
  /// * Persists the JWT access token via [ApiClient.saveToken].
  /// * The httpOnly `MOBILI_REFRESH` cookie is automatically stored by
  ///   `PersistCookieJar` (via the `CookieManager` interceptor).
  Future<AuthResponse> login({
    required String login,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'login': login, 'password': password},
      );
      final authResponse = AuthResponse.fromJson(response.data!);
      await ApiClient.instance.saveToken(authResponse.token);
      return authResponse;
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /auth/logout
  // ─────────────────────────────────────────────────────────────────────────

  /// Invalidates the refresh cookie server-side and clears the local session.
  ///
  /// Always clears local credentials even if the network call fails
  /// (best-effort logout pattern).
  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // Ignore network errors — local session is cleared regardless
    } finally {
      await ApiClient.instance.clearSession();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /auth/refresh
  // ─────────────────────────────────────────────────────────────────────────

  /// Manually refreshes the access token using the stored refresh cookie.
  ///
  /// Normally called automatically by the auth interceptor on 401; this method
  /// is exposed for cases where the caller needs explicit control (e.g.
  /// proactive pre-expiry refresh).
  Future<AuthResponse> refresh() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/auth/refresh');
      final authResponse = AuthResponse.fromJson(response.data!);
      await ApiClient.instance.saveToken(authResponse.token);
      return authResponse;
    } on DioException catch (e) {
      await ApiClient.instance.clearSession();
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /auth/register  (multipart/form-data)
  // ─────────────────────────────────────────────────────────────────────────

  /// Registers a new traveller account.
  ///
  /// [avatarFile] is optional. When provided it must be JPEG/PNG and ≤ 15 MB
  /// (validate client-side before calling this method).
  Future<ProfileDto> register({
    required String firstname,
    required String lastname,
    required String email,
    required String login,
    required String password,
    File? avatarFile,
  }) async {
    try {
      final formData = FormData.fromMap({
        'user': MultipartFile.fromString(
          jsonEncode({
            'firstname': firstname,
            'lastname': lastname,
            'email': email,
            'login': login,
            'password': password,
          }),
          contentType: DioMediaType('application', 'json'),
        ),
        if (avatarFile != null)
          'avatar': await MultipartFile.fromFile(
            avatarFile.path,
            filename: avatarFile.path.split('/').last,
          ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: formData,
      );
      return ProfileDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /auth/register-company  (multipart/form-data)
  // ─────────────────────────────────────────────────────────────────────────

  /// Registers a transport company and immediately authenticates the user.
  ///
  /// [companyData] must match the `RegisterCompanyPublicDTO` backend shape.
  Future<AuthResponse> registerCompany({
    required Map<String, dynamic> companyData,
    File? logoFile,
  }) async {
    try {
      final formData = FormData.fromMap({
        'company': MultipartFile.fromString(
          jsonEncode(companyData),
          contentType: DioMediaType('application', 'json'),
        ),
        if (logoFile != null)
          'logo': await MultipartFile.fromFile(
            logoFile.path,
            filename: logoFile.path.split('/').last,
          ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register-company',
        data: formData,
      );
      final authResponse = AuthResponse.fromJson(response.data!);
      await ApiClient.instance.saveToken(authResponse.token);
      return authResponse;
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /auth/register-carpool-chauffeur  (multipart/form-data)
  // ─────────────────────────────────────────────────────────────────────────

  /// Registers a solo carpool driver with KYC documents.
  ///
  /// All four image files are mandatory. Each must be ≤ 5 MB (KYC limit).
  Future<ProfileDto> registerCarpoolChauffeur({
    required Map<String, dynamic> userData,
    required File idFront,
    required File idBack,
    required File driverPhoto,
    required File vehiclePhoto,
  }) async {
    try {
      final formData = FormData.fromMap({
        'user': MultipartFile.fromString(
          jsonEncode(userData),
          contentType: DioMediaType('application', 'json'),
        ),
        'idFront': await MultipartFile.fromFile(
          idFront.path,
          filename: idFront.path.split('/').last,
        ),
        'idBack': await MultipartFile.fromFile(
          idBack.path,
          filename: idBack.path.split('/').last,
        ),
        'driverPhoto': await MultipartFile.fromFile(
          driverPhoto.path,
          filename: driverPhoto.path.split('/').last,
        ),
        'vehiclePhoto': await MultipartFile.fromFile(
          vehiclePhoto.path,
          filename: vehiclePhoto.path.split('/').last,
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register-carpool-chauffeur',
        data: formData,
      );
      return ProfileDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /auth/me
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches the currently authenticated user's profile (requires JWT).
  Future<ProfileDto> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return ProfileDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /auth/{id}
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches a user profile by [id]. Requires ADMIN role or ownership.
  Future<ProfileDto> getUserById(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/$id');
      return ProfileDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }
}
