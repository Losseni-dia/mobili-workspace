import 'package:json_annotation/json_annotation.dart';

part 'auth_response.g.dart';

/// Returned by POST /auth/login and POST /auth/refresh.
@JsonSerializable()
class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.login,
    required this.id,
    this.hasPartner,
  });

  /// JWT access token — valid 24 h.
  final String token;

  final String login;

  /// Backend user ID.
  final int id;

  /// Null until the user has linked a partner company.
  final bool? hasPartner;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  @override
  String toString() =>
      'AuthResponse(login: $login, id: $id, hasPartner: $hasPartner)';
}
