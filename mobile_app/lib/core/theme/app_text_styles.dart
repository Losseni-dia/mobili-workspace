import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Système typographique Mobili
///
/// Polices :
///   - Plus Jakarta Sans : titres (weight 900) — caractère, autorité
///   - Inter            : corps, labels, boutons — lisibilité mobile
///
/// À déclarer dans pubspec.yaml :
/// ```yaml
/// fonts:
///   - family: PlusJakartaSans
///     fonts:
///       - asset: assets/fonts/PlusJakartaSans-Regular.ttf
///       - asset: assets/fonts/PlusJakartaSans-SemiBold.ttf  weight: 600
///       - asset: assets/fonts/PlusJakartaSans-Bold.ttf      weight: 700
///       - asset: assets/fonts/PlusJakartaSans-ExtraBold.ttf weight: 800
///       - asset: assets/fonts/PlusJakartaSans-Black.ttf     weight: 900
///   - family: Inter
///     fonts:
///       - asset: assets/fonts/Inter-Regular.ttf
///       - asset: assets/fonts/Inter-Medium.ttf    weight: 500
///       - asset: assets/fonts/Inter-SemiBold.ttf  weight: 600
///       - asset: assets/fonts/Inter-Bold.ttf      weight: 700
/// ```
/// Ou via google_fonts :
/// ```dart
/// GoogleFonts.interTextTheme() + GoogleFonts.plusJakartaSans(...)
/// ```
abstract final class AppTextStyles {
  // ── Familles ──────────────────────────────────────────────────────────
  static const String _fontDisplay = 'PlusJakartaSans';
  static const String _fontBody    = 'Inter';

  // ── Tailles ───────────────────────────────────────────────────────────
  static const double _xs   = 11.0;
  static const double _sm   = 13.0;
  static const double _base = 16.0; // minimum mobile
  static const double _lg   = 18.0;
  static const double _xl   = 20.0;
  static const double _2xl  = 24.0;
  static const double _3xl  = 28.0;
  static const double _4xl  = 32.0;
  static const double _5xl  = 40.0;

  // ── Line heights ──────────────────────────────────────────────────────
  static const double _tight   = 1.15;
  static const double _snug    = 1.3;
  static const double _normal  = 1.5;
  static const double _relaxed = 1.65;

  // ─────────────────────────────────────────────────────────────────────
  // TITRES — Plus Jakarta Sans, weight 900, letter-spacing négatif
  // ─────────────────────────────────────────────────────────────────────

  /// Hero / splash — 40px
  static const TextStyle hero = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _5xl,
    fontWeight: FontWeight.w900,
    height: _tight,
    letterSpacing: -1.5,
    color: AppColors.mobiliBlueDeep,
  );

  /// Section principale — 32px
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _4xl,
    fontWeight: FontWeight.w900,
    height: _tight,
    letterSpacing: -1.0,
    color: AppColors.mobiliBlueDeep,
  );

  /// Titre de page — 28px
  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _3xl,
    fontWeight: FontWeight.w900,
    height: _tight,
    letterSpacing: -0.8,
    color: AppColors.mobiliBlueDeep,
  );

  /// Titre de section — 24px
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _2xl,
    fontWeight: FontWeight.w800,
    height: _snug,
    letterSpacing: -0.5,
    color: AppColors.mobiliBlueDeep,
  );

  /// Sous-titre — 20px
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _xl,
    fontWeight: FontWeight.w800,
    height: _snug,
    letterSpacing: -0.3,
    color: AppColors.mobiliBlueDeep,
  );

  /// Heading compact — 18px
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _lg,
    fontWeight: FontWeight.w700,
    height: _snug,
    color: AppColors.mobiliBlueDeep,
  );

  // ─────────────────────────────────────────────────────────────────────
  // TITRES DE CARD / LISTE — Inter semi-bold
  // ─────────────────────────────────────────────────────────────────────

  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontBody,
    fontSize: _lg,
    fontWeight: FontWeight.w700,
    height: _normal,
    color: AppColors.gray900,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w600,
    height: _normal,
    letterSpacing: 0.1,
    color: AppColors.gray900,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w600,
    height: _normal,
    letterSpacing: 0.1,
    color: AppColors.gray700,
  );

  // ─────────────────────────────────────────────────────────────────────
  // CORPS — Inter, 16px minimum
  // ─────────────────────────────────────────────────────────────────────

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w400,
    height: _relaxed,
    color: AppColors.gray800,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w400,
    height: _relaxed,
    color: AppColors.gray700,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: _xs,
    fontWeight: FontWeight.w400,
    height: _normal,
    color: AppColors.gray500,
  );

  // ─────────────────────────────────────────────────────────────────────
  // LABELS — Inter uppercase, weight 800
  // Convention Mobili : tous les labels de status/badge en majuscule
  // ─────────────────────────────────────────────────────────────────────

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: 1.2,
    color: AppColors.gray900,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 1.0,
    color: AppColors.gray700,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: _xs,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 1.2,
    color: AppColors.gray500,
  );

  // ─────────────────────────────────────────────────────────────────────
  // BOUTONS
  // ─────────────────────────────────────────────────────────────────────

  /// Bouton principal — Inter Bold 16px
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.3,
    color: AppColors.mobiliBlueDeep,  // texte bleu sur fond or
  );

  /// Bouton secondaire — Inter Bold 16px (texte blanc)
  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.3,
    color: AppColors.white,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.2,
  );

  // ─────────────────────────────────────────────────────────────────────
  // SPÉCIAUX
  // ─────────────────────────────────────────────────────────────────────

  /// Numéro de billet — monospace frappant
  static const TextStyle ticketCode = TextStyle(
    fontFamily: 'monospace',
    fontSize: _2xl,
    fontWeight: FontWeight.w900,
    height: 1.2,
    letterSpacing: 4.0,
    color: AppColors.mobiliBlue,
  );

  /// Prix / tarif
  static const TextStyle price = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _2xl,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -0.5,
    color: AppColors.mobiliBlue,
  );

  static const TextStyle priceSmall = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _lg,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: AppColors.mobiliBlue,
  );

  /// Libellé de champ de formulaire
  static const TextStyle inputLabel = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w600,
    height: _normal,
    letterSpacing: 0.3,
    color: AppColors.gray700,
  );

  /// Code erreur (monospace discret)
  static const TextStyle errorCode = TextStyle(
    fontFamily: 'monospace',
    fontSize: _xs,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 1.5,
    color: AppColors.danger,
  );

  // ─────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────

  static TextStyle withColor(TextStyle base, Color color) =>
      base.copyWith(color: color);

  /// Variante light pour texte sur fond sombre (header, cards bleu)
  static TextStyle onDark(TextStyle base) =>
      base.copyWith(color: AppColors.darkOnSurface);

  static TextStyle onDarkSub(TextStyle base) =>
      base.copyWith(color: AppColors.darkOnSurfaceVar);
}
