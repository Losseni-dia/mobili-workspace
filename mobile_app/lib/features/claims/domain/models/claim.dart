/// Résumé de la réservation liée — recalculé côté backend à la lecture depuis la relation
/// réelle (jamais figé), voir BookingSummaryResponse côté backend.
class ClaimBookingSummary {
  const ClaimBookingSummary({
    required this.bookingId,
    required this.reference,
    required this.route,
    required this.totalPrice,
    required this.status,
  });

  final int bookingId;
  final String reference;
  final String route;
  final double totalPrice;
  final String status;

  factory ClaimBookingSummary.fromJson(Map<String, dynamic> j) => ClaimBookingSummary(
        bookingId: (j['bookingId'] as num).toInt(),
        reference: j['reference'] as String? ?? '',
        route: j['route'] as String? ?? '',
        totalPrice: (j['totalPrice'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
      );
}

class Claim {
  const Claim({
    required this.id,
    required this.reason,
    required this.status,
    required this.message,
    required this.createdAt,
    this.booking,
    this.adminNote,
    this.resolvedAt,
  });

  final int id;
  final String reason;
  final String status;
  final ClaimBookingSummary? booking;
  final String message;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  factory Claim.fromJson(Map<String, dynamic> j) => Claim(
        id: (j['id'] as num).toInt(),
        reason: j['reason'] as String? ?? '',
        status: j['status'] as String? ?? '',
        booking: j['booking'] != null
            ? ClaimBookingSummary.fromJson(j['booking'] as Map<String, dynamic>)
            : null,
        message: j['message'] as String? ?? '',
        adminNote: j['adminNote'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        resolvedAt: j['resolvedAt'] != null
            ? DateTime.tryParse(j['resolvedAt'] as String)
            : null,
      );
}
