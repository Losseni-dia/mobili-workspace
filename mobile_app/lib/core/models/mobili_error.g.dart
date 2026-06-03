// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mobili_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MobiliError _$MobiliErrorFromJson(Map<String, dynamic> json) => MobiliError(
      timestamp: json['timestamp'] as String,
      status: (json['status'] as num).toInt(),
      errorCode: json['errorCode'] as String,
      message: json['message'] as String?,
      path: json['path'] as String?,
      errors: (json['errors'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$MobiliErrorToJson(MobiliError instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'status': instance.status,
      'errorCode': instance.errorCode,
      'message': instance.message,
      'path': instance.path,
      'errors': instance.errors,
    };
