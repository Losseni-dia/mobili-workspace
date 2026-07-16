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
    this.boardingCity,
    this.alightingCity,
    this.boardingStopIndex,
    this.alightingStopIndex,
    this.bookingDate,
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
  final String? boardingCity;
  final String? alightingCity;
  final int? boardingStopIndex;
  final int? alightingStopIndex;

  /// Date à laquelle le billet a été acheté — distincte de departureDateTime
  /// (la date du voyage lui-même).
  final DateTime? bookingDate;

  // Ville d'embarquement effective (tronçon si dispo, sinon départ complet)
  String get effectiveBoardingCity => boardingCity ?? departureCity;
  String get effectiveAlightingCity => alightingCity ?? arrivalCity;

  // Vrai si c'est un tronçon partiel
  bool get isPartialSegment =>
      boardingCity != null &&
      alightingCity != null &&
      (boardingCity != departureCity || alightingCity != arrivalCity);

  String get formattedPrice => '${price.toStringAsFixed(0)} FCFA';

  bool get _isCancelledStatus =>
      status.toUpperCase() == 'ANNULÉ' || status.toUpperCase() == 'CANCELLED';
  bool get _isArrivedStatus =>
      status.toUpperCase() == 'ARRIVÉ' || status.toUpperCase() == 'ARRIVE';
  bool get _isBoardedStatus =>
      status.toUpperCase() == 'UTILISÉ' || status.toUpperCase() == 'UTILISE';

  /// "À venir" = billet pas encore utilisé/arrivé/annulé, ET le voyage
  /// n'est pas encore passé (ou en cours d'embarquement — UTILISÉ reste
  /// "actif" même si l'heure de départ est dépassée).
  bool get belongsToUpcoming =>
      !_isCancelledStatus &&
      !_isArrivedStatus &&
      (_isBoardedStatus || departureDateTime.isAfter(DateTime.now()));

static const _monthLabels = [
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

  String get formattedDate {
    final d = departureDateTime;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_monthLabels[d.month]} · $h:$m';
  }

  /// Date d'achat formatée (ex. "5 juil. 2026 à 14:30") — null si non fournie
  /// par le backend (billets créés avant l'ajout de ce champ, par exemple).
  String? get formattedBookingDate {
    final d = bookingDate;
    if (d == null) return null;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return 'Acheté le ${d.day} ${_monthLabels[d.month]} ${d.year} à $h:$m';
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
        boardingCity: json['boardingCity'] as String?,
        alightingCity: json['alightingCity'] as String?,
       boardingStopIndex: json['boardingStopIndex'] as int?,
        alightingStopIndex: json['alightingStopIndex'] as int?,
        bookingDate: json['bookingDate'] != null
            ? DateTime.tryParse(json['bookingDate'] as String)
            : null,
      );
}
