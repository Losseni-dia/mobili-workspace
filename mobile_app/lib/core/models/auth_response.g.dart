// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
      token: json['token'] as String,
      login: json['login'] as String,
      id: (json['id'] as num).toInt(),
      hasPartner: json['hasPartner'] as bool?,
    );

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'token': instance.token,
      'login': instance.login,
      'id': instance.id,
      'hasPartner': instance.hasPartner,
    };
