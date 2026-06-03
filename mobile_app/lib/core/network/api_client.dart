import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/mobili_error.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

class ApiConstants {
  ApiConstants._();

   static const String baseUrlDev = 'http://10.0.2.2:8080/v1'; // Pour l'émulateur Android
  //static const String baseUrlDev = 'http://localhost:8080/v1';
  // Replace with real production domain before release
  static const String baseUrlProd = 'https://<domaine-prod>/v1';

  static const String baseUrl = baseUrlDev; // Toggle for build flavors

  /// Timeouts tuned for slow African mobile networks
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  static const String authHeader = 'Authorization';
  static const String contentTypeJson = 'application/json';

  // Secure storage key for the JWT access token
  static const String accessTokenKey = 'mobili_access_token';
}

// ─────────────────────────────────────────────────────────────────────────────
// ApiClient singleton
// ─────────────────────────────────────────────────────────────────────────────

class ApiClient {
  ApiClient._();

  static ApiClient? _instance;
  static ApiClient get instance => _instance!;

  late Dio dio;
  late PersistCookieJar _cookieJar;
  late FlutterSecureStorage _secureStorage;

  /// Must be called once at app startup (after path_provider is ready).
  static Future<ApiClient> init() async {
    if (_instance != null) return _instance!;

    final client = ApiClient._();
    await client._setup();
    _instance = client;
    return client;
  }

  Future<void> _setup() async {
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    // PersistCookieJar stores the httpOnly MOBILI_REFRESH cookie on disk
    final appDir = await getApplicationDocumentsDirectory();
    final cookieDir = Directory('${appDir.path}/.cookies');
    await cookieDir.create(recursive: true);
    _cookieJar = PersistCookieJar(storage: FileStorage(cookieDir.path));

    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        contentType: ApiConstants.contentTypeJson,
        responseType: ResponseType.json,
        // Don't throw on 4xx/5xx — we handle them in the interceptor
        validateStatus: (_) => true,
      ),
    );

    // 1. Cookie manager — must be added BEFORE auth interceptor
    dio.interceptors.add(CookieManager(_cookieJar));

    // 2. Auth interceptor (inject Bearer + auto-refresh on 401)
    dio.interceptors.add(_AuthInterceptor(
      dio: dio,
      secureStorage: _secureStorage,
      cookieJar: _cookieJar,
    ));

    // 3. Error normaliser (converts HTTP errors → MobiliException)
    dio.interceptors.add(_ErrorInterceptor());

    // Optional: log in debug builds
    // dio.interceptors.add(LogInterceptor(responseBody: true));
  }

  /// Convenience: store a new access token after login / refresh
  Future<void> saveToken(String token) =>
      _secureStorage.write(key: ApiConstants.accessTokenKey, value: token);

  /// Convenience: read the current access token
  Future<String?> readToken() =>
      _secureStorage.read(key: ApiConstants.accessTokenKey);

  /// Convenience: delete token + cookies on logout
  Future<void> clearSession() async {
    await _secureStorage.delete(key: ApiConstants.accessTokenKey);
    await _cookieJar.deleteAll();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth interceptor
// ─────────────────────────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({
    required this.dio,
    required this.secureStorage,
    required this.cookieJar,
  });

  final Dio dio;
  final FlutterSecureStorage secureStorage;
  final PersistCookieJar cookieJar;

  // Guard to prevent infinite refresh loops
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.read(key: ApiConstants.accessTokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers[ApiConstants.authHeader] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // Trigger refresh on 401, but only once and not for the refresh endpoint itself
    if (response.statusCode == 401 && !_isRefreshing) {
      final isRefreshEndpoint =
          response.requestOptions.path.contains('/auth/refresh');
      final isLoginEndpoint =
          response.requestOptions.path.contains('/auth/login');

      if (!isRefreshEndpoint && !isLoginEndpoint) {
        _isRefreshing = true;
        try {
          final refreshed = await _tryRefresh();
          if (refreshed != null) {
            // Retry the original request with the new token
            final retryOptions = response.requestOptions;
            retryOptions.headers[ApiConstants.authHeader] =
                'Bearer $refreshed';
            final retryResponse = await dio.fetch(retryOptions);
            _isRefreshing = false;
            return handler.resolve(retryResponse);
          }
        } catch (_) {
          // Refresh failed — fall through to deliver the 401 as-is
        } finally {
          _isRefreshing = false;
        }
      }
    }
    handler.next(response);
  }

  /// Calls POST /auth/refresh (cookie is sent automatically by CookieManager).
  /// Returns the new access token on success, null on failure.
  Future<String?> _tryRefresh() async {
    try {
      // Use a separate Dio instance to avoid interceptor loops
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
          validateStatus: (_) => true,
        ),
      );
      refreshDio.interceptors.add(CookieManager(cookieJar));

      final response =
          await refreshDio.post<Map<String, dynamic>>('/auth/refresh');

      if (response.statusCode == 200 && response.data != null) {
        final newToken = response.data!['token'] as String?;
        if (newToken != null) {
          await secureStorage.write(
            key: ApiConstants.accessTokenKey,
            value: newToken,
          );
          return newToken;
        }
      }
    } catch (_) {
      // Network error during refresh
    }
    // Clear session so the app redirects to login
    await secureStorage.delete(key: ApiConstants.accessTokenKey);
    await cookieJar.deleteAll();
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error interceptor
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final status = response.statusCode ?? 0;

    if (status >= 200 && status < 300) {
      handler.next(response);
      return;
    }

    // Try to parse as MobiliError
    try {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final mobiliError = MobiliError.fromJson(data);
        return handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            error: MobiliException.fromMobiliError(mobiliError),
            type: DioExceptionType.badResponse,
          ),
        );
      }
    } catch (_) {
      // Not a MobiliError body — fall through to generic
    }

    // Rate limiting (429) may not follow the standard MobiliError shape
    if (status == 429) {
      return handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: const MobiliException(
            status: 429,
            errorCode: 'RATE_LIMITED',
            message: 'Trop de requêtes — réessayez dans une minute.',
          ),
          type: DioExceptionType.badResponse,
        ),
      );
    }

    // Generic fallback
    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: MobiliException(
          status: status,
          errorCode: 'MOB-001',
          message: 'Une erreur inattendue est survenue ($status).',
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Network-level errors (no response)
    if (err.error is MobiliException) {
      handler.next(err);
      return;
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: const MobiliException(
            status: 0,
            errorCode: 'NETWORK_TIMEOUT',
            message: 'La connexion a expiré. Vérifiez votre réseau.',
          ),
          type: err.type,
        ),
      );
    }

    handler.next(err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: extract MobiliException from a DioException
// ─────────────────────────────────────────────────────────────────────────────

extension DioExceptionX on DioException {
  MobiliException get asMobili {
    if (error is MobiliException) return error as MobiliException;
    return MobiliException(
      status: response?.statusCode ?? 0,
      errorCode: 'MOB-001',
      message: message ?? 'Erreur réseau inconnue.',
    );
  }
}
