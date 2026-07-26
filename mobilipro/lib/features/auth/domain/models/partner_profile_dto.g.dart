// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'partner_profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PartnerProfileDto _$PartnerProfileDtoFromJson(Map<String, dynamic> json) =>
    PartnerProfileDto(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      logoUrl: json['logoUrl'] as String?,
      businessNumber: json['businessNumber'] as String?,
      enabled: json['enabled'] as bool,
      registrationCode: json['registrationCode'] as String?,
      approvalStatus: json['approvalStatus'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );

Map<String, dynamic> _$PartnerProfileDtoToJson(PartnerProfileDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'logoUrl': instance.logoUrl,
      'businessNumber': instance.businessNumber,
      'enabled': instance.enabled,
      'registrationCode': instance.registrationCode,
      'approvalStatus': instance.approvalStatus,
      'rejectionReason': instance.rejectionReason,
    };
