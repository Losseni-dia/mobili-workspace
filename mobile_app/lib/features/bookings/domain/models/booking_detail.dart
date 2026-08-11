class BookingDetail {
  const BookingDetail({
    required this.id,
    required this.reference,
    required this.status,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDateTime,
    required this.bookingDate,
    required this.totalPrice,
    required this.pricePerSeat,
    required this.numberOfSeats,
    required this.seatNumbers,
    required this.passengerNames,
    required this.customerName,
    this.tripId,
    required this.tripRoute,
    this.moreInfo,
    this.boardingCity,
    this.alightingCity,
    this.driverResponseDeadline,
    this.paymentDeadline,
    this.extraHoldBags = 0,
    this.luggageFee = 0,
    this.ticketsTotalAmount,
    this.serviceFee,
  });

  final int id;
  final String reference;
  final String status;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDateTime;
  final DateTime bookingDate;
  final double totalPrice;
  final double pricePerSeat;
  final int numberOfSeats;
  final List<String> seatNumbers;
  final List<String> passengerNames;
  final String customerName;
  final int? tripId;
  final String tripRoute;
  final String? moreInfo;
  final String? boardingCity;
  final String? alightingCity;
  final int extraHoldBags;
  final double luggageFee;

  /// Somme des prix de tickets SEULE (hors forfait client, hors bagages). Null sur les
  /// réservations créées avant le forfait client — voir [ticketsAmount].
  final double? ticketsTotalAmount;

  /// Forfait client appliqué (100/200/300 FCFA) — null sur les réservations antérieures.
  final int? serviceFee;

  /// Covoiturage : délai de réponse du chauffeur (24h après la demande).
  final DateTime? driverResponseDeadline;

  /// Covoiturage : délai de paiement une fois le chauffeur ayant accepté.
  final DateTime? paymentDeadline;

  bool get isUpcoming => departureDateTime.isAfter(DateTime.now());

  bool get _isResolvedNegatively =>
      status == 'CANCELLED' ||
      status == 'REJECTED_BY_DRIVER' ||
      status == 'EXPIRED';

  /// "À venir" = statut encore actif ET trajet pas encore passé. Une
  /// demande expirée/refusée/annulée bascule immédiatement en historique,
  /// même si la date du trajet est encore dans le futur.
  bool get belongsToUpcoming => !_isResolvedNegatively && isUpcoming;

  bool get canCancel =>
      (status == 'PENDING' || status == 'CONFIRMED') && isUpcoming;

  bool get isPendingDriverApproval => status == 'PENDING_DRIVER_APPROVAL';
  bool get isAwaitingPayment => status == 'AWAITING_PAYMENT';
  bool get isRejectedByDriver => status == 'REJECTED_BY_DRIVER';
  bool get isCovoiturageExpired => status == 'EXPIRED';

  String get formattedPrice => '${totalPrice.toStringAsFixed(0)} FCFA';

  /// Montant "réservation" pur — tickets seuls, sans le forfait client ni les bagages.
  /// C'est ce que "Mes réservations" doit afficher, pas [totalPrice]. Retombe sur
  /// [totalPrice] si [ticketsTotalAmount] est absent (réservation antérieure au forfait
  /// client — pas de recalcul rétroactif).
  double get ticketsAmount => ticketsTotalAmount ?? totalPrice;
  String get formattedTicketsAmount => '${ticketsAmount.toStringAsFixed(0)} FCFA';

  double get transportTotal => totalPrice - luggageFee;
  String get formattedTransportTotal =>
      '${transportTotal.toStringAsFixed(0)} FCFA';
  String get formattedLuggageFee => '${luggageFee.toStringAsFixed(0)} FCFA';

  String get formattedDate {
    final months = [
      '',
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'août',
      'sep',
      'oct',
      'nov',
      'déc'
    ];
    final d = departureDateTime;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month]} ${d.year} · $h:$m';
  }

  factory BookingDetail.fromJson(Map<String, dynamic> json) => BookingDetail(
        id: json['id'] as int,
        reference: json['reference'] as String? ?? '',
        status: json['status'] as String? ?? '',
        departureCity: json['departureCity'] as String? ?? '',
        arrivalCity: json['arrivalCity'] as String? ?? '',
        departureDateTime:
            DateTime.tryParse(json['departureDateTime'] as String? ?? '') ??
                DateTime.now(),
        bookingDate: DateTime.tryParse(json['bookingDate'] as String? ?? '') ??
            DateTime.now(),
        totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
        pricePerSeat: (json['pricePerSeat'] as num?)?.toDouble() ?? 0,
        numberOfSeats: json['numberOfSeats'] as int? ?? 1,
        seatNumbers: (json['seatNumbers'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        passengerNames: (json['passengerNames'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        customerName: json['customerName'] as String? ?? '',
        tripId: (json['tripId'] as num?)?.toInt(),
        tripRoute: json['tripRoute'] as String? ?? '',
        moreInfo: json['moreInfo'] as String?,
        boardingCity: json['boardingCity'] as String?,
        alightingCity: json['alightingCity'] as String?,
        driverResponseDeadline: json['driverResponseDeadline'] != null
            ? DateTime.tryParse(json['driverResponseDeadline'] as String)
            : null,
        paymentDeadline: json['paymentDeadline'] != null
            ? DateTime.tryParse(json['paymentDeadline'] as String)
            : null,
        extraHoldBags: (json['extraHoldBags'] as num?)?.toInt() ?? 0,
        luggageFee: (json['luggageFee'] as num?)?.toDouble() ?? 0,
        ticketsTotalAmount: (json['ticketsTotalAmount'] as num?)?.toDouble(),
        serviceFee: (json['serviceFee'] as num?)?.toInt(),
      );
}
