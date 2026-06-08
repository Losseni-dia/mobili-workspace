// ─────────────────────────────────────────────────────────────────────────────
// booking.dart
// ─────────────────────────────────────────────────────────────────────────────

class Booking {
  const Booking({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.seatNumber,
    required this.status,
    this.boardingStopIndex,
    this.alightingStopIndex,
    this.createdAt,
  });

  final int id;
  final int tripId;
  final int userId;
  final int seatNumber;
  final String status; // PENDING | CONFIRMED | COMPLETED | CANCELLED
  final int? boardingStopIndex;
  final int? alightingStopIndex;
  final DateTime? createdAt;

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as int,
        tripId: json['tripId'] as int? ?? 0,
        userId: json['userId'] as int? ?? 0,
        seatNumber: json['seatNumber'] as int? ?? 0,
        status: json['status'] as String? ?? 'PENDING',
        boardingStopIndex: json['boardingStopIndex'] as int?,
        alightingStopIndex: json['alightingStopIndex'] as int?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'userId': userId,
        'seatNumber': seatNumber,
        'status': status,
        if (boardingStopIndex != null) 'boardingStopIndex': boardingStopIndex,
        if (alightingStopIndex != null)
          'alightingStopIndex': alightingStopIndex,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// payment_result.dart
// ─────────────────────────────────────────────────────────────────────────────

class PaymentResult {
  const PaymentResult({required this.success, required this.status});

  final bool success;
  final String status;

 factory PaymentResult.fromJson(Map<String, dynamic> json) => PaymentResult(
        success: (json['success'] == true) ||
            json['status'] == 'CONFIRMED' ||
            json['status'] == 'COMPLETED',
        status: json['status'] as String? ?? 'PENDING',
      );
}