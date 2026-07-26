import 'package:json_annotation/json_annotation.dart';

part 'partner_profile_dto.g.dart';

@JsonSerializable()
class PartnerProfileDto {
  const PartnerProfileDto({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.logoUrl,
    this.businessNumber,
    required this.enabled,
    this.registrationCode,
    this.approvalStatus,
    this.rejectionReason,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? logoUrl;
  final String? businessNumber;
  final bool enabled;
  final String? registrationCode;
  final String? approvalStatus;
  final String? rejectionReason;

  factory PartnerProfileDto.fromJson(Map<String, dynamic> json) =>
      _$PartnerProfileDtoFromJson(json);

  Map<String, dynamic> toJson() => _$PartnerProfileDtoToJson(this);
}
