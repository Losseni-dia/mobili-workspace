import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// SystÃ¨me typographique Mobili
///
/// Polices :
///   - Plus Jakarta Sans : titres (weight 900) â€” caractÃ¨re, autoritÃ©
///   - fontFamily: GoogleFonts.inter().fontFamily,          : corps, labels, boutons â€” lisibilitÃ© mobile
///
/// Ã€ dÃ©clarer dans pubspec.yaml :
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
  // â”€â”€ Familles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final String _fontDisplay = GoogleFonts.plusJakartaSans().fontFamily!;
  static final String _fontBody    = GoogleFonts.inter().fontFamily!;

  // â”€â”€ Tailles â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const double _xs   = 11.0;
  static const double _sm   = 13.0;
  static const double _base = 16.0; // minimum mobile
  static const double _lg   = 18.0;
  static const double _xl   = 20.0;
  static const double _2xl  = 24.0;
  static const double _3xl  = 28.0;
  static const double _4xl  = 32.0;
  static const double _5xl  = 40.0;

  // â”€â”€ Line heights â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const double _tight   = 1.15;
  static const double _snug    = 1.3;
  static const double _normal  = 1.5;
  static const double _relaxed = 1.65;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // TITRES â€” Plus Jakarta Sans, weight 900, letter-spacing nÃ©gatif
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Hero / splash â€” 40px
  static TextStyle hero = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _5xl,
    fontWeight: FontWeight.w900,
    height: _tight,
    letterSpacing: -1.5,
    color: AppColors.mobiliBlueDeep,
  );

  /// Section principale â€” 32px
  static TextStyle displayLarge = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _4xl,
    fontWeight: FontWeight.w900,
    height: _tight,
    letterSpacing: -1.0,
    color: AppColors.mobiliBlueDeep,
  );

  static TextStyle get displaySmall => headlineLarge;

  /// Titre de page â€” 28px
  static TextStyle displayMedium = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _3xl,
    fontWeight: FontWeight.w900,
    height: _tight,
    letterSpacing: -0.8,
    color: AppColors.mobiliBlueDeep,
  );

  /// Titre de section â€” 24px
  static TextStyle headlineLarge = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _2xl,
    fontWeight: FontWeight.w800,
    height: _snug,
    letterSpacing: -0.5,
    color: AppColors.mobiliBlueDeep,
  );

  /// Sous-titre â€” 20px
  static TextStyle headlineMedium = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _xl,
    fontWeight: FontWeight.w800,
    height: _snug,
    letterSpacing: -0.3,
    color: AppColors.mobiliBlueDeep,
  );

  /// Heading compact â€” 18px
  static TextStyle headlineSmall = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _lg,
    fontWeight: FontWeight.w700,
    height: _snug,
    color: AppColors.mobiliBlueDeep,
  );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // TITRES DE CARD / LISTE â€” Inter semi-bold
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static TextStyle titleLarge = TextStyle(
    fontFamily: _fontBody,
    fontSize: _lg,
    fontWeight: FontWeight.w700,
    height: _normal,
    color: AppColors.gray900,
  );

  static TextStyle titleMedium = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w600,
    height: _normal,
    letterSpacing: 0.1,
    color: AppColors.gray900,
  );

  static TextStyle titleSmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w600,
    height: _normal,
    letterSpacing: 0.1,
    color: AppColors.gray700,
  );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // CORPS â€” Inter, 16px minimum
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static TextStyle bodyLarge = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w400,
    height: _relaxed,
    color: AppColors.gray800,
  );

  static TextStyle bodyMedium = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w400,
    height: _relaxed,
    color: AppColors.gray700,
  );

  static TextStyle bodySmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: _xs,
    fontWeight: FontWeight.w400,
    height: _normal,
    color: AppColors.gray500,
  );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // LABELS â€” Inter uppercase, weight 800
  // Convention Mobili : tous les labels de status/badge en majuscule
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static TextStyle labelLarge = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: 1.2,
    color: AppColors.gray900,
  );

  static TextStyle labelMedium = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 1.0,
    color: AppColors.gray700,
  );

  static TextStyle labelSmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: _xs,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 1.2,
    color: AppColors.gray500,
  );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // BOUTONS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Bouton principal â€” Inter Bold 16px
  static TextStyle buttonPrimary = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.3,
    color: AppColors.mobiliBlueDeep,  // texte bleu sur fond or
  );

  /// Bouton secondaire â€” Inter Bold 16px (texte blanc)
  static TextStyle buttonSecondary = TextStyle(
    fontFamily: _fontBody,
    fontSize: _base,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.3,
    color: AppColors.white,
  );

  static TextStyle buttonSmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.2,
  );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // SPÃ‰CIAUX
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// NumÃ©ro de billet â€” monospace frappant
  static TextStyle ticketCode = const TextStyle(
    fontFamily: 'monospace',
    fontSize: _2xl,
    fontWeight: FontWeight.w900,
    height: 1.2,
    letterSpacing: 4.0,
    color: AppColors.mobiliBlue,
  );

  /// Prix / tarif
  static TextStyle price = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _2xl,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -0.5,
    color: AppColors.mobiliBlue,
  );

  static TextStyle priceSmall = TextStyle(
    fontFamily: _fontDisplay,
    fontSize: _lg,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: AppColors.mobiliBlue,
  );

  /// LibellÃ© de champ de formulaire
  static TextStyle inputLabel = TextStyle(
    fontFamily: _fontBody,
    fontSize: _sm,
    fontWeight: FontWeight.w600,
    height: _normal,
    letterSpacing: 0.3,
    color: AppColors.gray700,
  );

  /// Code erreur (monospace discret)
  static TextStyle errorCode = const TextStyle(
    fontFamily: 'monospace',
    fontSize: _xs,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 1.5,
    color: AppColors.danger,
  );

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // HELPERS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static TextStyle withColor(TextStyle base, Color color) =>
      base.copyWith(color: color);

  /// Variante light pour texte sur fond sombre (header, cards bleu)
  static TextStyle onDark(TextStyle base) =>
      base.copyWith(color: AppColors.darkOnSurface);

  static TextStyle onDarkSub(TextStyle base) =>
      base.copyWith(color: AppColors.darkOnSurfaceVar);
}
