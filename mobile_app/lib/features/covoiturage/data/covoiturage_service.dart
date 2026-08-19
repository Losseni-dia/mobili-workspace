import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../auth/domain/models/profile_dto.dart';
import '../../trips/domain/models/trip.dart';

/// Data-layer service for the carpooling ("covoiturage" solo) driver space :
/// profile/KYC fields, and trip CRUD for the driver's own carpool trips.
///
/// Registration (`/auth/register-carpool-chauffeur`) lives in [AuthService]
/// since it's a public, unauthenticated endpoint — this service only covers
/// what's available to an already-authenticated CHAUFFEUR.
class CovoiturageService {
  CovoiturageService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  // ─────────────────────────────────────────────────────────────────────────
  // POST /covoiturage/profile/apply  (multipart/form-data)
  // ─────────────────────────────────────────────────────────────────────────

  /// A traveler who already has a Mobili account applies to become a
  /// carpool driver — attaches the covoiturage profile to the EXISTING
  /// account (adds the CHAUFFEUR role) instead of creating a second one,
  /// unlike `/auth/register-carpool-chauffeur`. Requires being logged in.
  Future<ProfileDto> applyAsDriver({
    required DateTime idValidUntil,
    required String vehicleBrand,
    required String vehiclePlate,
    required String vehicleColor,
    required String greyCardNumber,
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
      final formData = FormData.fromMap({
        'application': MultipartFile.fromString(
          jsonEncode({
            'idValidUntil': idValidUntil.toIso8601String().substring(0, 10),
            'vehicleBrand': vehicleBrand,
            'vehiclePlate': vehiclePlate,
            'vehicleColor': vehicleColor,
            'greyCardNumber': greyCardNumber,
          }),
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
        'licenseFront': await MultipartFile.fromFile(
          licenseFront.path,
          filename: licenseFront.path.split('/').last,
        ),
        'licenseBack': await MultipartFile.fromFile(
          licenseBack.path,
          filename: licenseBack.path.split('/').last,
        ),
        'greyCardFront': await MultipartFile.fromFile(
          greyCardFront.path,
          filename: greyCardFront.path.split('/').last,
        ),
        'greyCardBack': await MultipartFile.fromFile(
          greyCardBack.path,
          filename: greyCardBack.path.split('/').last,
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/covoiturage/profile/apply',
        data: formData,
      );
      return ProfileDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUT /covoiturage/profile  (multipart/form-data)
  // ─────────────────────────────────────────────────────────────────────────

  /// Updates vehicle info (brand/plate/color/grey card) and optionally
  /// replaces the driver/vehicle photos. KYC status and ID documents are not
  /// editable here — only an admin can change those.
  Future<ProfileDto> updateProfile({
    required String vehicleBrand,
    required String vehiclePlate,
    required String vehicleColor,
    required String greyCardNumber,
    File? driverPhoto,
    File? vehiclePhoto,
  }) async {
    try {
      final formData = FormData.fromMap({
        'profile': MultipartFile.fromString(
          jsonEncode({
            'vehicleBrand': vehicleBrand,
            'vehiclePlate': vehiclePlate,
            'vehicleColor': vehicleColor,
            'greyCardNumber': greyCardNumber,
          }),
          contentType: DioMediaType('application', 'json'),
        ),
        if (driverPhoto != null)
          'driverPhoto': await MultipartFile.fromFile(
            driverPhoto.path,
            filename: driverPhoto.path.split('/').last,
          ),
        if (vehiclePhoto != null)
          'vehiclePhoto': await MultipartFile.fromFile(
            vehiclePhoto.path,
            filename: vehiclePhoto.path.split('/').last,
          ),
      });

      final response = await _dio.put<Map<String, dynamic>>(
        '/covoiturage/profile',
        data: formData,
      );
      return ProfileDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /covoiturage/trips
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Trip>> getMyTrips() async {
    try {
      final response = await _dio.get<List<dynamic>>('/covoiturage/trips');
      return (response.data ?? [])
          .map((e) => Trip.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /covoiturage/trips  (multipart/form-data)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Trip> createTrip({
    required Map<String, dynamic> tripData,
    File? vehicleImage,
  }) async {
    try {
      final formData = FormData.fromMap({
        'trip': MultipartFile.fromString(
          jsonEncode(tripData),
          contentType: DioMediaType('application', 'json'),
        ),
        if (vehicleImage != null)
          'vehicleImage': await MultipartFile.fromFile(
            vehicleImage.path,
            filename: vehicleImage.path.split('/').last,
          ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/covoiturage/trips',
        data: formData,
      );
      return Trip.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUT /covoiturage/trips/{id}  (multipart/form-data)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Trip> updateTrip({
    required int id,
    required Map<String, dynamic> tripData,
    File? vehicleImage,
  }) async {
    try {
      final formData = FormData.fromMap({
        'trip': MultipartFile.fromString(
          jsonEncode(tripData),
          contentType: DioMediaType('application', 'json'),
        ),
        if (vehicleImage != null)
          'vehicleImage': await MultipartFile.fromFile(
            vehicleImage.path,
            filename: vehicleImage.path.split('/').last,
          ),
      });

      final response = await _dio.put<Map<String, dynamic>>(
        '/covoiturage/trips/$id',
        data: formData,
      );
      return Trip.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE /covoiturage/trips/{id}
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> deleteTrip(int id) async {
    try {
      await _dio.delete<void>('/covoiturage/trips/$id');
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

}
