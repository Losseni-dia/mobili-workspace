class Ticket {
  const Ticket({
    required this.ticketNumber,
    required this.qrCodeData,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDateTime,
    required this.passengerFullName,
    required this.seatNumber,
    required this.status,
    required this.price,
    required this.partnerName,
    required this.vehiculePlateNumber,
    required this.boardingPoint,
    required this.tripId,
  });

  final String ticketNumber;
  final String qrCodeData;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDateTime;
  final String passengerFullName;
  final String seatNumber;
  final String status;
  final double price;
  final String partnerName;
  final String vehiculePlateNumber;
  final String boardingPoint;
  final int tripId;

  String get formattedPrice => '${price.toStringAsFixed(0)} FCFA';

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
    return '${d.day} ${months[d.month]} · $h:$m';
  }

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        ticketNumber: json['ticketNumber'] as String? ?? '',
        qrCodeData: json['qrCodeData'] as String? ?? '',
        departureCity: json['departureCity'] as String? ?? '',
        arrivalCity: json['arrivalCity'] as String? ?? '',
        departureDateTime:
            DateTime.tryParse(json['departureDateTime'] as String? ?? '') ??
                DateTime.now(),
        passengerFullName: json['passengerFullName'] as String? ?? '',
        seatNumber: json['seatNumber']?.toString() ?? '0',
        status: json['status'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        partnerName: json['partnerName'] as String? ?? '',
        vehiculePlateNumber: json['vehiculePlateNumber'] as String? ?? '',
        boardingPoint: json['boardingPoint'] as String? ?? '',
        tripId: json['tripId'] as int? ?? 0,
      );
}
