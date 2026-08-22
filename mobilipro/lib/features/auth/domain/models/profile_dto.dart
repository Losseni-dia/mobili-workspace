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
    this.covoiturageSoloProfile,
    this.covoiturageKycStatus,
    this.partnerApprovalStatus,
    this.partnerRejectionReason,
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
  final String? partnerApprovalStatus; // PENDING | APPROVED | REJECTED
  final String? partnerRejectionReason;

  /// Conducteur covoiturage particulier (par opposition à un chauffeur
  /// salarié assigné par une compagnie/gare) — distinct du rôle CHAUFFEUR :
  /// un chauffeur compagnie a aussi ce rôle mais ne doit jamais avoir les
  /// actions covoiturage (créer/modifier/supprimer ses trajets).
  final bool? covoiturageSoloProfile;
  final String? covoiturageKycStatus; // NONE | PENDING | APPROVED | REJECTED | EXPIRED

  // ---------------------------------------------------------------------------
  // Role helpers
  // ---------------------------------------------------------------------------

  bool get isUser => roles.contains('USER');
  bool get isPartner => roles.contains('PARTNER');
  // Depuis la migration du login gare vers StationPrincipal (authentification par
  // code station), une session gare renvoie roles: ["STATION"], plus jamais "GARE".
  // Même fix que web (AuthService.hasRole) : sans le synonyme, le guard de rôle
  // /gare/* de go_router.dart renvoyait systématiquement l'utilisateur vers
  // /gare/dashboard dès qu'il tapait un autre onglet (rien n'était cliquable).
  bool get isGare => roles.contains('GARE') || roles.contains('STATION');
  bool get isChauffeur => roles.contains('CHAUFFEUR');
  bool get isAdmin => roles.contains('ADMIN');

  /// Vrai uniquement pour un conducteur covoiturage avec KYC validé — c'est
  /// la seule condition qui autorise à créer/modifier/supprimer un trajet.
bool get isCovoiturageDriver =>
      covoiturageSoloProfile == true && covoiturageKycStatus == 'APPROVED';

  bool get isPartnerPending => isPartner && partnerApprovalStatus == 'PENDING';
  bool get isPartnerRejected =>
      isPartner && partnerApprovalStatus == 'REJECTED';

  String get fullName => '$firstname $lastname';
/////////////////////////////5v

























































































  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileDtoToJson(this);

  @override
  String toString() => 'ProfileDto(id: $id, login: $login, roles: $roles)';
}
