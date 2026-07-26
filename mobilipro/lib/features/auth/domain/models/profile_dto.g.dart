// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileDto _$ProfileDtoFromJson(Map<String, dynamic> json) => ProfileDto(
  id: (json['id'] as num).toInt(),
  firstname: json['firstname'] as String,
  lastname: json['lastname'] as String,
  email: json['email'] as String?,
  phone: json['phone'] as String?,
  login: json['login'] as String,
  roles: (json['roles'] as List<dynamic>).map((e) => e as String).toList(),
  enabled: json['enabled'] as bool,
  avatarUrl: json['avatarUrl'] as String?,
  covoiturageSoloProfile: json['covoiturageSoloProfile'] as bool?,
  covoiturageKycStatus: json['covoiturageKycStatus'] as String?,
  partnerApprovalStatus: json['partnerApprovalStatus'] as String?,
  partnerRejectionReason: json['partnerRejectionReason'] as String?,
);

Map<String, dynamic> _$ProfileDtoToJson(ProfileDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'firstname': instance.firstname,
      'lastname': instance.lastname,
      'email': instance.email,
      'phone': instance.phone,
      'login': instance.login,
      'avatarUrl': instance.avatarUrl,
      'roles': instance.roles,
      'enabled': instance.enabled,
      'partnerApprovalStatus': instance.partnerApprovalStatus,
      'partnerRejectionReason': instance.partnerRejectionReason,
      'covoiturageSoloProfile': instance.covoiturageSoloProfile,
      'covoiturageKycStatus': instance.covoiturageKycStatus,
    };
