import 'package:json_annotation/json_annotation.dart';

part 'profile_dto.g.dart';

/// Returned by GET /auth/me, GET /auth/{id}, and the registration endpoints.
///
/// Additional role-specific fields (gare, covoiturage) are present in the
/// backend response but omitted here until required by the UI.
@JsonSerializable()
class ProfileDto {
  const ProfileDto({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.login,
    required this.roles,
    required this.enabled,
    this.avatarUrl,
  });

  final int id;
  final String firstname;
  final String lastname;
  final String email;
  final String login;
  final String? avatarUrl;
  final List<String> roles;
  final bool enabled;

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
  // Serialisation
  // ---------------------------------------------------------------------------

  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDtoFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileDtoToJson(this);

  @override
  String toString() => 'ProfileDto(id: $id, login: $login, roles: $roles)';
}
