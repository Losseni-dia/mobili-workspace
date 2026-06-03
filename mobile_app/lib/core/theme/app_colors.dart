import 'package:flutter/material.dart';

/// Charte couleurs officielle Mobili — traduite depuis variables.scss
/// Ne pas modifier sans mettre à jour le frontend Angular en parallèle.
///
/// Palette : Bleu profond autoritaire + Or/Jaune signature d'action
/// Style   : Premium transport urbain africain
abstract final class AppColors {
  // ── Couleurs Mobili principales ──────────────────────────────────────
  static const Color mobiliYellow     = Color(0xFFFFCC00);
  static const Color mobiliYellowSoft = Color(0xFFFFE27A);
  static const Color mobiliYellowDark = Color(0xFFE6B800);

  static const Color mobiliBlue      = Color(0xFF092990);
  static const Color mobiliBlueDeep  = Color(0xFF05164D);
  static const Color mobiliBlueLight = Color(0xFF1E3AC0);
  static const Color mobiliBlueFog   = Color(0xFFEEF1FF);
  static const Color mobiliBlueSoft  = Color(0xFFD6DEFF); // hover states

  // ── Rôles / badges ───────────────────────────────────────────────────
  static const Color adminPurple      = Color(0xFF6B21A8);
  static const Color adminPurpleSoft  = Color(0xFFF3E8FF);
  static const Color stationGreen     = Color(0xFF15803D);
  static const Color stationGreenSoft = Color(0xFFDCFCE7);

  // ── Sémantique ────────────────────────────────────────────────────────
  static const Color success     = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color danger      = Color(0xFFDC2626);
  static const Color dangerSoft  = Color(0xFFFEE2E2);
  static const Color warning     = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);

  // ── Neutres ───────────────────────────────────────────────────────────
  static const Color white   = Color(0xFFFFFFFF);
  static const Color gray50  = Color(0xFFF8FAFF); // background app
  static const Color gray100 = Color(0xFFF1F4FB);
  static const Color gray200 = Color(0xFFE2E8F0);
  static const Color gray300 = Color(0xFFCBD5E1);
  static const Color gray400 = Color(0xFF94A3B8);
  static const Color gray500 = Color(0xFF64748B);
  static const Color gray600 = Color(0xFF475569);
  static const Color gray700 = Color(0xFF334155);
  static const Color gray800 = Color(0xFF1E293B);
  static const Color gray900 = Color(0xFF0F172A);

  // ── Dark mode surfaces ────────────────────────────────────────────────
  static const Color darkBg          = Color(0xFF060D2B); // bleu nuit profond
  static const Color darkSurface     = Color(0xFF0C1640);
  static const Color darkSurfaceRaised = Color(0xFF122060);
  static const Color darkOutline     = Color(0xFF1E3A8A);
  static const Color darkOnSurface   = Color(0xFFE2E8FF);
  static const Color darkOnSurfaceVar = Color(0xFF94A3C8);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient gradientHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mobiliBlue, mobiliBlueDeep],
  );

  /// Gradient gold — fond des boutons primaires CTA
  static const LinearGradient gradientGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mobiliYellow, mobiliYellowDark],
  );

  static const LinearGradient gradientGoldVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [mobiliYellow, mobiliYellowDark],
  );

  static const LinearGradient gradientCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [white, mobiliBlueFog],
  );

  /// Gradient header dark (AppBar, hero sections)
  static const LinearGradient gradientHeaderDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D2280), mobiliBlueDeep],
  );

  // ── Ombres ────────────────────────────────────────────────────────────
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0F05164D), blurRadius: 10, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1405164D), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x1E05164D), blurRadius: 45, offset: Offset(0, 20)),
  ];

  /// Halo gold — sous les boutons CTA jaunes
  static const List<BoxShadow> shadowGold = [
    BoxShadow(color: Color(0x73FFCC00), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> shadowBlue = [
    BoxShadow(color: Color(0x40092990), blurRadius: 20, offset: Offset(0, 8)),
  ];

  // ── Statuts booking ───────────────────────────────────────────────────
  static const Color statusConfirmed = success;
  static const Color statusConfirmedBg = successSoft;
  static const Color statusPending = warning;
  static const Color statusPendingBg = warningSoft;
  static const Color statusCancelled = danger;
  static const Color statusCancelledBg = dangerSoft;
  static const Color statusCompleted = mobiliBlue;
  static const Color statusCompletedBg = mobiliBlueFog;

  // ── Helpers ───────────────────────────────────────────────────────────
  /// Retourne la couleur de fond associée à un statut booking
  static Color bookingStatusBg(String status) => switch (status.toUpperCase()) {
        'CONFIRMED' => statusConfirmedBg,
        'PENDING' => statusPendingBg,
        'CANCELLED' => statusCancelledBg,
        'COMPLETED' => statusCompletedBg,
        _ => gray100,
      };

  static Color bookingStatusFg(String status) => switch (status.toUpperCase()) {
        'CONFIRMED' => statusConfirmed,
        'PENDING' => statusPending,
        'CANCELLED' => statusCancelled,
        'COMPLETED' => statusCompleted,
        _ => gray500,
      };
}
