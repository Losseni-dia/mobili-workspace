class PaymentResponse {
  final int paymentId;
  final int bookingId;
  final String provider;
  final String status;
  final String paymentUrl;
  final String? clientSecret;
  final int amount;
  final String currency;

  PaymentResponse({
    required this.paymentId,
    required this.bookingId,
    required this.provider,
    required this.status,
    required this.paymentUrl,
    this.clientSecret,
    required this.amount,
    required this.currency,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      paymentId: json['paymentId'] as int,
      bookingId: json['bookingId'] as int,
      provider: json['provider'] as String,
      status: json['status'] as String,
      paymentUrl: json['paymentUrl'] as String,
      clientSecret: json['clientSecret'] as String?,
      amount: json['amount'] as int,
      currency: json['currency'] as String,
    );
  }
}
