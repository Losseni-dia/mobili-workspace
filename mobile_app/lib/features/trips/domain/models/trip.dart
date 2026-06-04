import 'package:intl/intl.dart';

class Trip {
  const Trip({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureTime,
    this.arrivalTime,
    required this.totalSeats,
    required this.availableSeats,
    required this.priceXof,
    this.transportType,
    this.partnerName,
    this.legFares,
    this.vehicleImageUrl,
    this.moreInfo,
    this.boardingPoint,
    this.vehicleType,
  });

  final int id;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureTime;
  final DateTime? arrivalTime;
  final int totalSeats;
  final int availableSeats;
  final double priceXof;
  final String? transportType;
  final String? partnerName;
  final List<LegFare>? legFares;
  final String? vehicleImageUrl;
  final String? moreInfo;
  final String? boardingPoint;
  final String? vehicleType;

  String get formattedDepartureTime =>
      DateFormat('dd/MM HH:mm').format(departureTime);

  String? get formattedArrivalTime =>
      arrivalTime != null ? DateFormat('HH:mm').format(arrivalTime!) : null;

  String get formattedPrice => '${priceXof.toStringAsFixed(0)} FCFA';

  /// Ex: "22 août à 12:05"
  String get formattedDepartureFull {
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
    final d = departureTime;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month]} à $h:$m';
  }

  /// Libellé lisible du type de véhicule
  String get vehicleTypeLabel {
    switch (vehicleType?.toUpperCase()) {
      case 'BUS_CLIMATISE':
        return 'Bus Climatisé';
      case 'BUS_CLASSIQUE':
        return 'Bus Classique';
      case 'CAR_70_PLACES':
        return 'Car 70 places';
      case 'MINIBUS':
        return 'Minibus';
      case 'MASSA_NORMAL':
        return 'Massa';
      case 'MASSA_6_ROUES':
        return 'Massa 6 roues';
      case 'CITADINE':
        return 'Citadine';
      case 'SUV':
        return 'SUV';
      default:
        return vehicleType ?? '';
    }
  }

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as int,
        departureCity: json['departureCity'] as String? ??
            json['departure'] as String? ??
            '',
        arrivalCity:
            json['arrivalCity'] as String? ?? json['arrival'] as String? ?? '',
        departureTime: _parseDate(json['departureDateTime']) ??
            _parseDate(json['departureTime']) ??
            DateTime.now(),
        arrivalTime: _parseDate(json['arrivalTime']),
        totalSeats: json['totalSeats'] as int? ?? 0,
        availableSeats: json['availableSeats'] as int? ?? 0,
        priceXof: (json['price'] as num?)?.toDouble() ??
            (json['priceXof'] as num?)?.toDouble() ??
            0,
        transportType: json['transportType'] as String?,
        partnerName: json['partnerName'] as String?,
        legFares: json['legFares'] != null
            ? (json['legFares'] as List<dynamic>)
                .map((e) => LegFare.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
        vehicleImageUrl: json['vehicleImageUrl'] as String?,
        moreInfo: json['moreInfo'] as String?,
        boardingPoint: json['boardingPoint'] as String?,
        vehicleType: json['vehicleType'] as String?,
      );

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      final clean = value.toString().replaceAll(RegExp(r'\.\d+'), '');
      try {
        return DateTime.parse(clean);
      } catch (_) {
        return null;
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
        'departureTime': departureTime.toIso8601String(),
        if (arrivalTime != null) 'arrivalTime': arrivalTime!.toIso8601String(),
        'totalSeats': totalSeats,
        'availableSeats': availableSeats,
        'price': priceXof,
        if (transportType != null) 'transportType': transportType,
        if (partnerName != null) 'partnerName': partnerName,
        if (legFares != null)
          'legFares': legFares!.map((lf) => lf.toJson()).toList(),
        if (vehicleImageUrl != null) 'vehicleImageUrl': vehicleImageUrl,
        if (moreInfo != null) 'moreInfo': moreInfo,
        if (boardingPoint != null) 'boardingPoint': boardingPoint,
        if (vehicleType != null) 'vehicleType': vehicleType,
      };
}

class LegFare {
  const LegFare({
    required this.fromCity,
    required this.toCity,
    required this.priceXof,
  });

  final String fromCity;
  final String toCity;
  final double priceXof;

  String get formattedPrice => '${priceXof.toStringAsFixed(0)} FCFA';

  factory LegFare.fromJson(Map<String, dynamic> json) => LegFare(
        fromCity: json['fromCity'] as String? ?? '',
        toCity: json['toCity'] as String? ?? '',
        priceXof: (json['price'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'fromCity': fromCity,
        'toCity': toCity,
        'price': priceXof,
      };
}
