import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primaires Mobili ─────────────────────────────────────────────
  static const Color mobiliBlue = Color(0xFF1B2A6B);
  static const Color mobiliBlueDeep = Color(0xFF0A1F6E);
  static const Color mobiliBlueFog = Color(0xFFEEF2FF);
  static const Color mobiliYellow = Color(0xFFF5C400);

  // ── Accent Pro ───────────────────────────────────────────────────
  static const Color proGold = Color(0xFFE8A020);
  static const Color proGoldSoft = Color(0xFFFFF3DC);

  // ── Statuts ──────────────────────────────────────────────────────
  static const Color stationGreen = Color(0xFF16A34A);
  static const Color stationGreenSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);

  // ── Neutres ──────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFF8F9FC);
  static const Color gray100 = Color(0xFFF1F5F9);
  static const Color gray200 = Color(0xFFE2E8F0);
  static const Color gray300 = Color(0xFFCBD5E1);
  static const Color gray400 = Color(0xFF94A3B8);
  static const Color gray500 = Color(0xFF64748B);
  static const Color gray600 = Color(0xFF475569);
  static const Color gray700 = Color(0xFF334155);

  // ── Dark ─────────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);

  // ── Shadows ──────────────────────────────────────────────────────
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4)),
  ];
}
