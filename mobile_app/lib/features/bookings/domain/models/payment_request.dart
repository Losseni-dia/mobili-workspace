class PaymentRequest {
  final String provider;
  final String? customerEmail;

  PaymentRequest({required this.provider, this.customerEmail});

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'customerEmail': customerEmail,
  };
}
