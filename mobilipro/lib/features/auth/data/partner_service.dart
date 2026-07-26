import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/partner_profile_dto.dart';

class PartnerService {
  PartnerService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;
  final Dio _dio;

  Future<PartnerProfileDto> getMyCompany() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/partners/my-company',
      );
      return PartnerProfileDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }

  Future<PartnerProfileDto> updateCompany({
    required int id,
    required Map<String, dynamic> companyData,
    File? logoFile,
    File? kycFrontFile,
    File? kycBackFile,
  }) async {
    try {
      final formData = FormData.fromMap({
        'partner': MultipartFile.fromString(
          jsonEncode(companyData),
         contentType: DioMediaType('application', 'json'),
        ),
        if (logoFile != null)
          'logo': await MultipartFile.fromFile(
            logoFile.path,
            filename: logoFile.path.split('/').last,
          ),
        if (kycFrontFile != null)
          'kycFront': await MultipartFile.fromFile(
            kycFrontFile.path,
            filename: kycFrontFile.path.split('/').last,
          ),
        if (kycBackFile != null)
          'kycBack': await MultipartFile.fromFile(
            kycBackFile.path,
            filename: kycBackFile.path.split('/').last,
          ),
      });

      final response = await _dio.put<Map<String, dynamic>>(
        '/partners/$id',
        data: formData,
      );
      return PartnerProfileDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.asMobili;
    }
  }
}
