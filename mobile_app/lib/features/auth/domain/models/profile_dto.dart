import 'package:json_annotation/json_annotation.dart';

part 'profile_dto.g.dart';

@JsonSerializable()
class ProfileDto {
  const ProfileDto({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.email,
    this.phone,
    required this.login,
    required this.roles,
    required this.enabled,
    this.avatarUrl,
    this.covoiturageKycStatus,
    this.covoiturageIdValidUntil,
    this.covoiturageVehicleBrand,
    this.covoiturageVehiclePlate,
    this.covoiturageVehicleColor,
    this.covoiturageGreyCardNumber,
    this.covoiturageVehiclePhotoUrl,
    this.covoiturageDriverPhotoUrl,
    this.covoiturageKycDaysUntilExpiry,
    this.covoiturageKycExpiringWithin30Days,
    this.covoiturageKycIsDocumentExpired,
    this.covoiturageSoloProfile,
  });

  final int id;
  final String firstname;
  final String lastname;
  final String? email; // ← optionnel
  final String? phone; // ← nouveau
  final String login;
  final String? avatarUrl;
  final List<String> roles;
  final bool enabled;

  // ── Covoiturage (conducteur particulier) ──────────────────────────────────
  final String? covoiturageKycStatus; // NONE | PENDING | APPROVED | REJECTED | EXPIRED
  final String? covoiturageIdValidUntil; // yyyy-MM-dd
  final String? covoiturageVehicleBrand;
  final String? covoiturageVehiclePlate;
  final String? covoiturageVehicleColor;
  final String? covoiturageGreyCardNumber;
  final String? covoiturageVehiclePhotoUrl;
  final String? covoiturageDriverPhotoUrl;
  final int? covoiturageKycDaysUntilExpiry;
  final bool? covoiturageKycExpiringWithin30Days;
  final bool? covoiturageKycIsDocumentExpired;
  final bool? covoiturageSoloProfile;

  // ---------------------------------------------------------------------------
  // Role helpers
  // ---------------------------------------------------------------------------

  bool get isUser => roles.contains('USER');
  bool get isPartner => roles.contains('PARTNER');
  bool get isGare => roles.contains('GARE');
  bool get isChauffeur => roles.contains('CHAUFFEUR');
  bool get isAdmin => roles.contains('ADMIN');

  String get fullName => '$firstname $lastname';

  // ---------------------------------------------------------------------------
  // Covoiturage helpers
  // ---------------------------------------------------------------------------

  /// True si l'utilisateur a déjà soumis un dossier conducteur covoiturage
  /// (quel que soit le statut KYC).
  bool get hasCovoiturageProfile =>
      covoiturageSoloProfile == true || covoiturageKycStatus != null;

  bool get covoiturageKycApproved => covoiturageKycStatus == 'APPROVED';
  bool get covoiturageKycPending => covoiturageKycStatus == 'PENDING';
  bool get covoiturageKycRejected => covoiturageKycStatus == 'REJECTED';
  bool get covoiturageKycExpired => covoiturageKycStatus == 'EXPIRED';

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileDtoToJson(this);

  @override
  String toString() => 'ProfileDto(id: $id, login: $login, roles: $roles)';
}
