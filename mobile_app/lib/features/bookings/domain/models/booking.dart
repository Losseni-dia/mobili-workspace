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
    this.driverResponseDeadline,
    this.paymentDeadline,
    this.customerFirstname,
    this.customerLastname,
    this.customerAvatarUrl,
    this.numberOfSeats,
  });

  final int id;
  final int tripId;
  final int userId;
  final int seatNumber;
  final String status; // PENDING | CONFIRMED | COMPLETED | CANCELLED |
  // PENDING_DRIVER_APPROVAL | AWAITING_PAYMENT | REJECTED_BY_DRIVER | EXPIRED
  final int? boardingStopIndex;
  final int? alightingStopIndex;
  final DateTime? createdAt;

  /// Covoiturage : délai de réponse du chauffeur (24h après création).
  final DateTime? driverResponseDeadline;

  /// Covoiturage : délai de paiement une fois le chauffeur ayant accepté.
  final DateTime? paymentDeadline;

  /// Utile côté chauffeur pour évaluer une demande (pas d'email/téléphone).
  final String? customerFirstname;
  final String? customerLastname;
  final String? customerAvatarUrl;
  final int? numberOfSeats;

  bool get isPendingDriverApproval => status == 'PENDING_DRIVER_APPROVAL';
  bool get isAwaitingPayment => status == 'AWAITING_PAYMENT';
  bool get isRejectedByDriver => status == 'REJECTED_BY_DRIVER';
  bool get isExpired => status == 'EXPIRED';
  String get customerFullName =>
      '${customerFirstname ?? ''} ${customerLastname ?? ''}'.trim();

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
        driverResponseDeadline: json['driverResponseDeadline'] != null
            ? DateTime.tryParse(json['driverResponseDeadline'] as String)
            : null,
        paymentDeadline: json['paymentDeadline'] != null
            ? DateTime.tryParse(json['paymentDeadline'] as String)
            : null,
        customerFirstname: json['customerFirstname'] as String?,
        customerLastname: json['customerLastname'] as String?,
        customerAvatarUrl: json['customerAvatarUrl'] as String?,
        numberOfSeats: json['numberOfSeats'] as int?,
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
