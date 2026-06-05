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

  bool get isUpcoming => departureDateTime.isAfter(DateTime.now());

  bool get canCancel =>
      (status == 'PENDING' || status == 'CONFIRMED') && isUpcoming;

  String get formattedPrice => '${totalPrice.toStringAsFixed(0)} FCFA';

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
      );
}
