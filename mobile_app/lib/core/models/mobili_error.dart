import 'package:json_annotation/json_annotation.dart';

part 'mobili_error.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MobiliError — raw JSON shape returned by the backend
// ─────────────────────────────────────────────────────────────────────────────

/// Standard error envelope from the Mobili API.
///
/// Two variants exist:
/// * Regular errors → [message] is populated.
/// * Validation errors (MOB-003 / HTTP 400) → [errors] map is populated
///   instead, keyed by field name.
@JsonSerializable()
class MobiliError {
  const MobiliError({
    required this.timestamp,
    required this.status,
    required this.errorCode,
    this.message,
    this.path,
    this.errors,
  });

  final String timestamp;
  final int status;
  final String errorCode;

  /// Human-readable message (absent for validation errors).
  final String? message;

  /// Request path that triggered the error.
  final String? path;

  /// Field-level validation errors (only present when errorCode == "MOB-003").
  final Map<String, String>? errors;

  factory MobiliError.fromJson(Map<String, dynamic> json) =>
      _$MobiliErrorFromJson(json);

  Map<String, dynamic> toJson() => _$MobiliErrorToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// MobiliException — typed Dart exception thrown by ApiClient interceptors
// ─────────────────────────────────────────────────────────────────────────────

/// All known Mobili error codes.
enum MobiliErrorCode {
  mob001, // 500 — generic server error
  mob002, // 404 — resource not found
  mob003, // 400 — validation error (see validationErrors)
  mob004, // 409 — duplicate (email, license plate…)
  auth001, // 401 — bad credentials
  auth002, // 403 — insufficient role
  trp001, // 409 — no seats available
  trp002, // 409 — boarding closed
  bkg001, // 400 — booking already cancelled
  bkg002, // 409 — ticket already used
  bkg003, // 409 — ticket cancelled
  bkg004, // 409 — ticket expired
  pay001, // 409 — insufficient balance
  vhc001, // 409 — vehicle already assigned
  rateLimited, // 429 — too many requests
  networkTimeout, // client-side timeout
  unknown,
}

class MobiliException implements Exception {
  const MobiliException({
    required this.status,
    required this.errorCode,
    required this.message,
    this.validationErrors,
    this.path,
  });

  final int status;

  /// Raw code string from the API (e.g. "MOB-002", "AUTH-001").
  final String errorCode;

  /// User-facing message ready to display.
  final String message;

  /// Only populated when [errorCode] == "MOB-003".
  final Map<String, String>? validationErrors;

  final String? path;

  // ---------------------------------------------------------------------------
  // Factory: build from a parsed MobiliError JSON object
  // ---------------------------------------------------------------------------

  factory MobiliException.fromMobiliError(MobiliError err) {
    // Validation errors carry a map, not a single message
    if (err.errorCode == 'MOB-003' && err.errors != null) {
      final summary = err.errors!.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n');
      return MobiliException(
        status: err.status,
        errorCode: err.errorCode,
        message: _localizeCode(err.errorCode, summary),
        validationErrors: err.errors,
        path: err.path,
      );
    }

    return MobiliException(
      status: err.status,
      errorCode: err.errorCode,
      message: _localizeCode(err.errorCode, err.message),
      path: err.path,
    );
  }

  // ---------------------------------------------------------------------------
  // Typed code accessor
  // ---------------------------------------------------------------------------

  MobiliErrorCode get typedCode {
    switch (errorCode) {
      case 'MOB-001':
        return MobiliErrorCode.mob001;
      case 'MOB-002':
        return MobiliErrorCode.mob002;
      case 'MOB-003':
        return MobiliErrorCode.mob003;
      case 'MOB-004':
        return MobiliErrorCode.mob004;
      case 'AUTH-001':
        return MobiliErrorCode.auth001;
      case 'AUTH-002':
        return MobiliErrorCode.auth002;
      case 'TRP-001':
        return MobiliErrorCode.trp001;
      case 'TRP-002':
        return MobiliErrorCode.trp002;
      case 'BKG-001':
        return MobiliErrorCode.bkg001;
      case 'BKG-002':
        return MobiliErrorCode.bkg002;
      case 'BKG-003':
        return MobiliErrorCode.bkg003;
      case 'BKG-004':
        return MobiliErrorCode.bkg004;
      case 'PAY-001':
        return MobiliErrorCode.pay001;
      case 'VHC-001':
        return MobiliErrorCode.vhc001;
      case 'RATE_LIMITED':
        return MobiliErrorCode.rateLimited;
      case 'NETWORK_TIMEOUT':
        return MobiliErrorCode.networkTimeout;
      default:
        return MobiliErrorCode.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Convenience booleans
  // ---------------------------------------------------------------------------

  bool get isAuthError =>
      typedCode == MobiliErrorCode.auth001 ||
      typedCode == MobiliErrorCode.auth002;

  bool get isValidationError => typedCode == MobiliErrorCode.mob003;

  bool get isRateLimited => typedCode == MobiliErrorCode.rateLimited;

  bool get isTimeout => typedCode == MobiliErrorCode.networkTimeout;

  // ---------------------------------------------------------------------------
  // Localised user-facing messages (French — primary locale for Afrique)
  // ---------------------------------------------------------------------------

  static String _localizeCode(String code, String? serverMessage) {
    switch (code) {
      case 'MOB-001':
        return 'Une erreur serveur est survenue. Veuillez réessayer.';
      case 'MOB-002':
        return 'La ressource demandée est introuvable.';
      case 'MOB-003':
        return serverMessage ?? 'Certaines données saisies sont invalides.';
      case 'MOB-004':
        return 'Cette information existe déjà (doublon).';
      case 'AUTH-001':
        return 'Identifiant ou mot de passe incorrect.';
      case 'AUTH-002':
        return "Vous n'avez pas les droits nécessaires.";
      case 'TRP-001':
        return 'Plus de places disponibles sur ce trajet.';
      case 'TRP-002':
        return 'Les réservations sont fermées — le départ a déjà été enregistré.';
      case 'BKG-001':
        return 'Cette réservation a déjà été annulée.';
      case 'BKG-002':
        return 'Ce ticket a déjà été utilisé.';
      case 'BKG-003':
        return 'Ce ticket a été annulé.';
      case 'BKG-004':
        return 'Ce ticket est expiré.';
      case 'PAY-001':
        return 'Solde insuffisant pour effectuer ce paiement.';
      case 'VHC-001':
        return 'Ce véhicule est déjà assigné à un trajet.';
      case 'RATE_LIMITED':
        return 'Trop de requêtes — réessayez dans une minute.';
      case 'NETWORK_TIMEOUT':
        return 'La connexion a expiré. Vérifiez votre réseau et réessayez.';
      default:
        return serverMessage ?? 'Une erreur inattendue est survenue.';
    }
  }

  @override
  String toString() =>
      'MobiliException[$errorCode] status=$status — $message';
}
