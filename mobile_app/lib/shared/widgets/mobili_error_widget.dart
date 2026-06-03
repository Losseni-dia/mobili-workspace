import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle d'erreur — miroir de MobiliError Spring Boot
// ─────────────────────────────────────────────────────────────────────────────

/// Représentation cliente d'une erreur API Mobili
/// Correspond au format JSON : { timestamp, status, errorCode, message, path, errors? }
class MobiliErrorData {
  const MobiliErrorData({
    required this.errorCode,
    required this.message,
    this.status,
    this.fieldErrors,
  });

  factory MobiliErrorData.generic([String? msg]) => MobiliErrorData(
        errorCode: 'ERR',
        message: msg ?? 'Une erreur inattendue est survenue.',
      );

  factory MobiliErrorData.network() => const MobiliErrorData(
        errorCode: 'NET',
        message: 'Connexion impossible. Vérifiez votre réseau.',
      );

  factory MobiliErrorData.fromJson(Map<String, dynamic> json) =>
      MobiliErrorData(
        errorCode: json['errorCode'] as String? ?? 'ERR',
        message: json['message'] as String? ?? 'Erreur inconnue.',
        status: json['status'] as int?,
        fieldErrors: json['errors'] != null
            ? Map<String, String>.from(json['errors'] as Map)
            : null,
      );

  final String errorCode;
  final String message;
  final int? status;
  final Map<String, String>? fieldErrors;

  bool get hasFieldErrors => fieldErrors?.isNotEmpty == true;
  bool get isNetworkError => errorCode == 'NET';
  bool get isAuthError =>
      errorCode == 'AUTH-001' || errorCode == 'AUTH-002';

  /// Message lisible — traduit les codes techniques
  String get userMessage => switch (errorCode) {
        'AUTH-001'    => 'Identifiant ou mot de passe incorrect.',
        'AUTH-002'    => 'Accès refusé. Droits insuffisants.',
        'MOB-001'     => 'Erreur serveur. Réessayez dans quelques instants.',
        'MOB-002'     => 'Ressource introuvable.',
        'MOB-003'     => 'Veuillez corriger les champs indiqués.',
        'MOB-004'     => 'Cette entrée existe déjà (doublon).',
        'TRP-001'     => 'Plus de places disponibles sur ce trajet.',
        'TRP-002'     => 'Embarquement fermé — le trajet a déjà démarré.',
        'BKG-001'     => 'Cette réservation est déjà annulée.',
        'BKG-002'     => 'Ce ticket a déjà été utilisé.',
        'BKG-003'     => 'Ce ticket est annulé.',
        'BKG-004'     => 'Ce ticket a expiré.',
        'PAY-001'     => 'Solde insuffisant pour effectuer ce paiement.',
        'VHC-001'     => 'Ce véhicule est déjà assigné à un autre trajet.',
        'RATE_LIMITED'=> 'Trop de tentatives. Réessayez dans une minute.',
        'NET'         => 'Connexion impossible. Vérifiez votre réseau.',
        _             => message,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL — plein écran / section
// ─────────────────────────────────────────────────────────────────────────────

/// Bloc d'erreur principal — occupe toute la section ou la page
///
/// ```dart
/// // Depuis une exception MobiliException
/// MobiliErrorWidget(
///   error: MobiliErrorData.fromJson(e.response.data),
///   onRetry: _reload,
/// )
///
/// // Erreur réseau
/// MobiliErrorWidget(
///   error: MobiliErrorData.network(),
///   onRetry: _reload,
/// )
/// ```
class MobiliErrorWidget extends StatelessWidget {
  const MobiliErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel = 'Réessayer',
  });

  final MobiliErrorData error;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final _Palette p = _palette(isDark);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icône ────────────────────────────────────────────────
            _IconCircle(
              icon: _iconFor(error.errorCode),
              iconColor: p.iconColor,
              bgColor: p.iconBg,
              ringColor: p.ring,
            ),
            const SizedBox(height: 20),

            // ── Badge code ───────────────────────────────────────────
            _CodeBadge(code: error.errorCode, palette: p),
            const SizedBox(height: 12),

            // ── Message ──────────────────────────────────────────────
            Text(
              error.userMessage,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                color: isDark ? AppColors.darkOnSurface : AppColors.mobiliBlueDeep,
                fontWeight: FontWeight.w600,
              ),
            ),

            // ── Erreurs de champ ─────────────────────────────────────
            if (error.hasFieldErrors) ...[
              const SizedBox(height: 16),
              _FieldErrorList(
                errors: error.fieldErrors!,
                fgColor: p.iconColor,
              ),
            ],

            // ── Retry ────────────────────────────────────────────────
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              _RetryButton(
                label: retryLabel,
                onTap: onRetry!,
                fgColor: p.iconColor,
                borderColor: p.ring,
              ),
            ],
          ],
        ),
      ),
    );
  }

  _Palette _palette(bool isDark) {
    final bool isAuth = error.isAuthError;
    final bool isNet  = error.isNetworkError;

    if (isNet) {
      return _Palette(
        iconColor: isDark ? AppColors.mobiliYellowSoft : AppColors.warning,
        iconBg: isDark
            ? const Color(0xFF2A2000)
            : AppColors.warningSoft,
        ring: isDark
            ? const Color(0xFF5C4400)
            : const Color(0xFFFFD966),
      );
    }
    if (isAuth) {
      return _Palette(
        iconColor: isDark ? const Color(0xFFBBADFF) : AppColors.adminPurple,
        iconBg: isDark
            ? const Color(0xFF1E1040)
            : AppColors.adminPurpleSoft,
        ring: isDark
            ? const Color(0xFF3D1F80)
            : const Color(0xFFDDD6FE),
      );
    }
    return _Palette(
      iconColor: isDark ? const Color(0xFFFF8080) : AppColors.danger,
      iconBg: isDark ? const Color(0xFF2A0C0C) : AppColors.dangerSoft,
      ring: isDark ? const Color(0xFF5C1A1A) : const Color(0xFFFCA5A5),
    );
  }

  IconData _iconFor(String code) => switch (code) {
        'AUTH-001'    => Icons.lock_outline_rounded,
        'AUTH-002'    => Icons.shield_outlined,
        'MOB-002'     => Icons.search_off_rounded,
        'MOB-001'     => Icons.cloud_off_outlined,
        'TRP-001'     => Icons.event_seat_outlined,
        'TRP-002'     => Icons.directions_bus_outlined,
        'BKG-001' || 'BKG-002' || 'BKG-003' || 'BKG-004' =>
          Icons.confirmation_number_outlined,
        'PAY-001'     => Icons.account_balance_wallet_outlined,
        'RATE_LIMITED'=> Icons.hourglass_top_rounded,
        'NET'         => Icons.wifi_off_rounded,
        _             => Icons.warning_amber_rounded,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// BANDEAU INLINE — en haut d'un formulaire ou section
// ─────────────────────────────────────────────────────────────────────────────

/// Bandeau d'erreur inline compact
/// ```dart
/// MobiliErrorBanner(
///   message: error.userMessage,
///   onDismiss: () => setState(() => _error = null),
/// )
/// ```
class MobiliErrorBanner extends StatelessWidget {
  const MobiliErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.variant = _BannerVariant.error,
  });

  const MobiliErrorBanner.warning({
    super.key,
    required this.message,
    this.onDismiss,
  }) : variant = _BannerVariant.warning;

  final String message;
  final VoidCallback? onDismiss;
  final _BannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bg, border, icon, text;

    switch (variant) {
      case _BannerVariant.error:
        bg     = isDark ? const Color(0xFF2A0C0C) : AppColors.dangerSoft;
        border = isDark ? const Color(0xFF5C1A1A) : const Color(0xFFFCA5A5);
        icon   = isDark ? const Color(0xFFFF8080) : AppColors.danger;
        text   = isDark ? AppColors.darkOnSurface : AppColors.gray800;
      case _BannerVariant.warning:
        bg     = isDark ? const Color(0xFF2A2000) : AppColors.warningSoft;
        border = isDark ? const Color(0xFF5C4400) : const Color(0xFFFFD966);
        icon   = isDark ? AppColors.mobiliYellowSoft : AppColors.warning;
        text   = isDark ? AppColors.darkOnSurface : AppColors.gray800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            variant == _BannerVariant.warning
                ? Icons.info_outline_rounded
                : Icons.error_outline_rounded,
            size: 20,
            color: icon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 18, color: icon),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERREURS DE CHAMP (MOB-003 — validation @Valid)
// ─────────────────────────────────────────────────────────────────────────────

/// Liste des erreurs de validation champ par champ
/// ```dart
/// MobiliFieldErrors(errors: {'email': 'must not be blank'})
/// ```
class MobiliFieldErrors extends StatelessWidget {
  const MobiliFieldErrors({super.key, required this.errors});
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fg =
        isDark ? const Color(0xFFFF8080) : AppColors.danger;
    final Color bgRow =
        isDark ? const Color(0xFF2A0C0C) : const Color(0xFFFFF5F5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgRow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: errors.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 5, color: fg),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_label(e.key)} ',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: e.value,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: fg),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(String key) => switch (key) {
        'email'     => 'Email :',
        'password'  => 'Mot de passe :',
        'login'     => 'Identifiant :',
        'firstname' => 'Prénom :',
        'lastname'  => 'Nom :',
        'phone'     => 'Téléphone :',
        _           => '$key :',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets privés
// ─────────────────────────────────────────────────────────────────────────────

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.ringColor,
  });
  final IconData icon;
  final Color iconColor, bgColor, ringColor;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor.withValues(alpha: 0.5),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(color: ringColor, width: 1.5),
            ),
            child: Icon(icon, size: 36, color: iconColor),
          ),
        ],
      );
}

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.code, required this.palette});
  final String code;
  final _Palette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: palette.iconBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.ring),
        ),
        child: Text(
          code,
          style: AppTextStyles.errorCode.copyWith(color: palette.iconColor),
        ),
      );
}

class _FieldErrorList extends StatelessWidget {
  const _FieldErrorList(
      {required this.errors, required this.fgColor});
  final Map<String, String> errors;
  final Color fgColor;

  @override
  Widget build(BuildContext context) =>
      MobiliFieldErrors(errors: errors);
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.label,
    required this.onTap,
    required this.fgColor,
    required this.borderColor,
  });
  final String label;
  final VoidCallback onTap;
  final Color fgColor, borderColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 200,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(Icons.refresh_rounded, size: 18, color: fgColor),
          label: Text(label,
              style: AppTextStyles.buttonSmall.copyWith(color: fgColor)),
          style: OutlinedButton.styleFrom(
            foregroundColor: fgColor,
            side: BorderSide(color: borderColor, width: 1.5),
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
}

class _Palette {
  const _Palette(
      {required this.iconColor,
      required this.iconBg,
      required this.ring});
  final Color iconColor, iconBg, ring;
}

enum _BannerVariant { error, warning }
