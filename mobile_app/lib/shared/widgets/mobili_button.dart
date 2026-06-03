import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Variantes de bouton Mobili
enum MobiliButtonVariant {
  primary,   // Gradient gold — action principale CTA
  secondary, // Fond mobiliBlue — action secondaire
  outlined,  // Bordure mobiliBlue — tertiaire light mode / bordure gold dark mode
  ghost,     // Transparent + texte — lien/action discret
  danger,    // Rouge DC2626 — suppression / annulation destructive
}

/// Tailles de bouton
enum MobiliButtonSize { large, medium, small }

/// Bouton Mobili — composant central du design system
///
/// Le bouton [primary] utilise un gradient gold (LinearGradient) avec
/// texte mobiliBlueDeep, respectant le contraste WCAG AA.
/// Le halo gold est désactivé sur low-end (optionnel via [showShadow]).
///
/// Usage rapide :
/// ```dart
/// // CTA principal
/// MobiliButton(label: 'Réserver', onPressed: _book)
///
/// // Secondaire
/// MobiliButton.secondary(label: 'Voir trajets', onPressed: _browse)
///
/// // État loading (désactive le tap automatiquement)
/// MobiliButton(label: 'Paiement…', isLoading: true, onPressed: null)
///
/// // Danger
/// MobiliButton.danger(label: 'Annuler le billet', onPressed: _cancel)
///
/// // Compact, non plein-largeur
/// MobiliButton(
///   label: 'Valider',
///   fullWidth: false,
///   size: MobiliButtonSize.small,
///   onPressed: _confirm,
/// )
/// ```
class MobiliButton extends StatelessWidget {
  const MobiliButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.variant = MobiliButtonVariant.primary,
    this.size = MobiliButtonSize.large,
    this.fullWidth = true,
    this.enabled = true,
    this.showShadow = true,
  });

  // Named constructors ──────────────────────────────────────────────────
  const MobiliButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.size = MobiliButtonSize.large,
    this.fullWidth = true,
    this.enabled = true,
    this.showShadow = true,
  }) : variant = MobiliButtonVariant.secondary;

  const MobiliButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.size = MobiliButtonSize.large,
    this.fullWidth = true,
    this.enabled = true,
    this.showShadow = false,
  }) : variant = MobiliButtonVariant.outlined;

  const MobiliButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.size = MobiliButtonSize.large,
    this.fullWidth = true,
    this.enabled = true,
    this.showShadow = false,
  }) : variant = MobiliButtonVariant.ghost;

  const MobiliButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.size = MobiliButtonSize.large,
    this.fullWidth = true,
    this.enabled = true,
    this.showShadow = false,
  }) : variant = MobiliButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final MobiliButtonVariant variant;
  final MobiliButtonSize size;
  final bool fullWidth;
  final bool enabled;

  /// Halo / ombre dorée sous le CTA — désactiver sur très low-end
  final bool showShadow;

  // ── Sizing ────────────────────────────────────────────────────────────
  double get _height => switch (size) {
        MobiliButtonSize.large  => 52.0,
        MobiliButtonSize.medium => 44.0,
        MobiliButtonSize.small  => 36.0,
      };

  EdgeInsets get _padding => switch (size) {
        MobiliButtonSize.large  => const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        MobiliButtonSize.medium => const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        MobiliButtonSize.small  => const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      };

  double get _fontSize => switch (size) {
        MobiliButtonSize.large  => 16.0,
        MobiliButtonSize.medium => 14.0,
        MobiliButtonSize.small  => 13.0,
      };

  double get _iconSize => switch (size) {
        MobiliButtonSize.large  => 20.0,
        MobiliButtonSize.medium => 18.0,
        MobiliButtonSize.small  => 16.0,
      };

  double get _radius => switch (size) {
        MobiliButtonSize.large  => 14.0,
        MobiliButtonSize.medium => 10.0,
        MobiliButtonSize.small  => 8.0,
      };

  double get _loaderSize => switch (size) {
        MobiliButtonSize.large  => 20.0,
        MobiliButtonSize.medium => 18.0,
        MobiliButtonSize.small  => 14.0,
      };

  // ── Config couleurs ───────────────────────────────────────────────────
  _BtnConfig _config(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool dis = !enabled || isLoading;

    if (dis) {
      return _BtnConfig(
        gradient: null,
        bgColor: isDark ? AppColors.darkOutline : AppColors.gray200,
        fgColor: isDark ? AppColors.darkOnSurfaceVar : AppColors.gray400,
        borderColor: null,
        shadow: null,
        loaderColor: isDark ? AppColors.darkOnSurfaceVar : AppColors.gray400,
      );
    }

    return switch (variant) {
      // ── Primary : gradient gold ──────────────────────────────────────
      MobiliButtonVariant.primary => _BtnConfig(
          gradient: AppColors.gradientGold,
          bgColor: null,
          fgColor: AppColors.mobiliBlueDeep,
          borderColor: null,
          shadow: showShadow ? AppColors.shadowGold : null,
          loaderColor: AppColors.mobiliBlueDeep,
        ),

      // ── Secondary : bleu uni ──────────────────────────────────────────
      MobiliButtonVariant.secondary => _BtnConfig(
          gradient: null,
          bgColor: isDark ? AppColors.mobiliBlueLight : AppColors.mobiliBlue,
          fgColor: AppColors.white,
          borderColor: null,
          shadow: showShadow ? AppColors.shadowBlue : null,
          loaderColor: AppColors.white,
        ),

      // ── Outlined ──────────────────────────────────────────────────────
      MobiliButtonVariant.outlined => _BtnConfig(
          gradient: null,
          bgColor: Colors.transparent,
          fgColor: isDark ? AppColors.mobiliYellowSoft : AppColors.mobiliBlue,
          borderColor:
              isDark ? AppColors.mobiliYellowSoft : AppColors.mobiliBlue,
          shadow: null,
          loaderColor:
              isDark ? AppColors.mobiliYellowSoft : AppColors.mobiliBlue,
        ),

      // ── Ghost ─────────────────────────────────────────────────────────
      MobiliButtonVariant.ghost => _BtnConfig(
          gradient: null,
          bgColor: Colors.transparent,
          fgColor: isDark ? AppColors.mobiliYellow : AppColors.mobiliBlue,
          borderColor: null,
          shadow: null,
          loaderColor:
              isDark ? AppColors.mobiliYellow : AppColors.mobiliBlue,
        ),

      // ── Danger ────────────────────────────────────────────────────────
      MobiliButtonVariant.danger => _BtnConfig(
          gradient: null,
          bgColor: AppColors.danger,
          fgColor: AppColors.white,
          borderColor: null,
          shadow: null,
          loaderColor: AppColors.white,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config(context);
    final bool isDisabled = !enabled || isLoading;

    final Widget innerContent = isLoading
        ? _Loader(size: _loaderSize, color: cfg.loaderColor)
        : _Content(
            label: label,
            icon: icon,
            trailingIcon: trailingIcon,
            fgColor: cfg.fgColor,
            fontSize: _fontSize,
            iconSize: _iconSize,
          );

    // Décoration du container selon gradient/couleur unie/outlined
    BoxDecoration decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(_radius),
      gradient: cfg.gradient,
      color: cfg.gradient == null ? cfg.bgColor : null,
      border: cfg.borderColor != null
          ? Border.all(color: cfg.borderColor!, width: 2)
          : null,
      boxShadow: (cfg.shadow != null && !isDisabled) ? cfg.shadow : null,
    );

    Widget button = Opacity(
      opacity: isDisabled ? 0.55 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(_radius),
          splashColor: cfg.fgColor.withValues(alpha: 0.15),
          highlightColor: cfg.fgColor.withValues(alpha: 0.08),
          child: Container(
            height: _height,
            padding: _padding,
            decoration: decoration,
            child: Center(child: innerContent),
          ),
        ),
      ),
    );

    if (fullWidth) return SizedBox(width: double.infinity, child: button);
    return IntrinsicWidth(child: button);
  }
}

// ── Contenu du bouton ─────────────────────────────────────────────────────
class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    required this.fgColor,
    required this.fontSize,
    required this.iconSize,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color fgColor;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: fgColor),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: AppTextStyles.buttonPrimary.copyWith(
            color: fgColor,
            fontSize: fontSize,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: iconSize, color: fgColor),
        ],
      ],
    );
  }
}

// ── Spinner de chargement ─────────────────────────────────────────────────
class _Loader extends StatelessWidget {
  const _Loader({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          backgroundColor: color.withValues(alpha: 0.2),
        ),
      );
}

// ── Data class config ─────────────────────────────────────────────────────
class _BtnConfig {
  const _BtnConfig({
    required this.gradient,
    required this.bgColor,
    required this.fgColor,
    required this.borderColor,
    required this.shadow,
    required this.loaderColor,
  });
  final LinearGradient? gradient;
  final Color? bgColor;
  final Color fgColor;
  final Color? borderColor;
  final List<BoxShadow>? shadow;
  final Color loaderColor;
}
