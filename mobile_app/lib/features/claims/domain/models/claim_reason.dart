import 'package:flutter/material.dart';

/// Config de PRÉSENTATION uniquement (libellé, icône, quelle étape afficher) — la vraie
/// règle métier (ClaimReason.requiresBooking()) vit côté backend, source de vérité. Ajouter
/// un nouveau motif plus tard = une valeur ici + son pendant dans l'enum backend, rien
/// d'autre à reconstruire dans le formulaire (voir ClaimFormPage, entièrement piloté par
/// cette liste).
enum ClaimReasonType {
  refundRequest,
  cancellation,
  delay,
  driverIssue,
  lostItem,
  other;

  /// Valeur exacte attendue par le backend (ClaimReason, module/claim/enums).
  String get apiValue => switch (this) {
        ClaimReasonType.refundRequest => 'REFUND_REQUEST',
        ClaimReasonType.cancellation => 'CANCELLATION',
        ClaimReasonType.delay => 'DELAY',
        ClaimReasonType.driverIssue => 'DRIVER_ISSUE',
        ClaimReasonType.lostItem => 'LOST_ITEM',
        ClaimReasonType.other => 'OTHER',
      };

  String get label => switch (this) {
        ClaimReasonType.refundRequest => 'Demande de remboursement',
        ClaimReasonType.cancellation => "Demande d'annulation",
        ClaimReasonType.delay => 'Retard important',
        ClaimReasonType.driverIssue => 'Problème avec le chauffeur',
        ClaimReasonType.lostItem => 'Objet perdu',
        ClaimReasonType.other => 'Autre',
      };

  IconData get icon => switch (this) {
        ClaimReasonType.refundRequest => Icons.payments_outlined,
        ClaimReasonType.cancellation => Icons.event_busy_rounded,
        ClaimReasonType.delay => Icons.schedule_rounded,
        ClaimReasonType.driverIssue => Icons.person_off_outlined,
        ClaimReasonType.lostItem => Icons.inventory_2_outlined,
        ClaimReasonType.other => Icons.help_outline_rounded,
      };

  /// Reflète ClaimReason.requiresBooking() côté backend — utilisé seulement pour savoir
  /// quelle étape afficher dans le formulaire, jamais comme validation finale (le backend
  /// revalide et rejette proprement si une réservation manquante était attendue).
  bool get requiresBooking => switch (this) {
        ClaimReasonType.refundRequest ||
        ClaimReasonType.cancellation ||
        ClaimReasonType.delay ||
        ClaimReasonType.driverIssue =>
          true,
        ClaimReasonType.lostItem || ClaimReasonType.other => false,
      };

  /// Retrouve le type de présentation à partir de la valeur brute renvoyée par le backend
  /// (ex. dans Claim.reason) — utilisé par l'écran "Mes réclamations" pour afficher le bon
  /// libellé/icône sans dupliquer le mapping.
  static ClaimReasonType fromApiValue(String value) => ClaimReasonType.values.firstWhere(
        (r) => r.apiValue == value,
        orElse: () => ClaimReasonType.other,
      );
}
