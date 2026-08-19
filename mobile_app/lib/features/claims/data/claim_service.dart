import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/claim.dart';
import '../domain/models/claim_reason.dart';

class ClaimService {
  ClaimService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  /// POST /claims — le userId n'est jamais envoyé par le client, il est
  /// résolu côté backend depuis le token (voir ClaimController.createClaim),
  /// même principe que POST /bookings.
  Future<Claim> createClaim({
    required ClaimReasonType reason,
    int? bookingId,
    required String message,
    Map<String, String>? details,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/claims',
      data: {
        'reason': reason.apiValue,
        if (bookingId != null) 'bookingId': bookingId,
        'message': message,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
    return Claim.fromJson(response.data!);
  }

  /// Étape optionnelle après createClaim() : joint une preuve (image ou PDF) à une
  /// réclamation existante — propriété vérifiée côté backend (ClaimService.addAttachment).
  Future<Claim> addAttachment(int claimId, File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/claims/$claimId/attachment',
      data: formData,
    );
    return Claim.fromJson(response.data!);
  }

  Future<List<Claim>> getMyClaims(int userId) async {
    final response = await _dio.get<List<dynamic>>('/claims/mine/$userId');
    if (response.data == null) return [];
    return (response.data as List<dynamic>)
        .map((e) => Claim.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
