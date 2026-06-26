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
      covoiturageKycStatus: json['covoiturageKycStatus'] as String?,
      covoiturageIdValidUntil: json['covoiturageIdValidUntil'] as String?,
      covoiturageVehicleBrand: json['covoiturageVehicleBrand'] as String?,
      covoiturageVehiclePlate: json['covoiturageVehiclePlate'] as String?,
      covoiturageVehicleColor: json['covoiturageVehicleColor'] as String?,
      covoiturageGreyCardNumber: json['covoiturageGreyCardNumber'] as String?,
      covoiturageVehiclePhotoUrl: json['covoiturageVehiclePhotoUrl'] as String?,
      covoiturageDriverPhotoUrl: json['covoiturageDriverPhotoUrl'] as String?,
      covoiturageKycDaysUntilExpiry:
          (json['covoiturageKycDaysUntilExpiry'] as num?)?.toInt(),
      covoiturageKycExpiringWithin30Days:
          json['covoiturageKycExpiringWithin30Days'] as bool?,
      covoiturageKycIsDocumentExpired:
          json['covoiturageKycIsDocumentExpired'] as bool?,
      covoiturageSoloProfile: json['covoiturageSoloProfile'] as bool?,
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
      'covoiturageKycStatus': instance.covoiturageKycStatus,
      'covoiturageIdValidUntil': instance.covoiturageIdValidUntil,
      'covoiturageVehicleBrand': instance.covoiturageVehicleBrand,
      'covoiturageVehiclePlate': instance.covoiturageVehiclePlate,
      'covoiturageVehicleColor': instance.covoiturageVehicleColor,
      'covoiturageGreyCardNumber': instance.covoiturageGreyCardNumber,
      'covoiturageVehiclePhotoUrl': instance.covoiturageVehiclePhotoUrl,
      'covoiturageDriverPhotoUrl': instance.covoiturageDriverPhotoUrl,
      'covoiturageKycDaysUntilExpiry': instance.covoiturageKycDaysUntilExpiry,
      'covoiturageKycExpiringWithin30Days':
          instance.covoiturageKycExpiringWithin30Days,
      'covoiturageKycIsDocumentExpired':
          instance.covoiturageKycIsDocumentExpired,
      'covoiturageSoloProfile': instance.covoiturageSoloProfile,
    };
