/// Résultat de POST /payments/verify/{bookingId} (voir PaymentVerifyResponse
/// côté backend : record(boolean confirmed, String status)). `status` est le
/// statut de la RÉSERVATION (PENDING/AWAITING_PAYMENT/CONFIRMED/COMPLETED),
/// pas un statut de paiement — ne pas comparer à 'SUCCESS'.
class PaymentVerificationResponse {
  final bool confirmed;
  final String status;

  PaymentVerificationResponse({
    required this.confirmed,
    required this.status,
  });

  factory PaymentVerificationResponse.fromJson(Map<String, dynamic> json) {
    return PaymentVerificationResponse(
      confirmed: json['confirmed'] as bool,
      status: json['status'] as String,
    );
  }
}
