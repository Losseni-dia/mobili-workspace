import 'package:intl/intl.dart';

class TripStop {
  const TripStop({
    required this.id,
    required this.cityName,
    this.scheduledTime,
    this.stopIndex,
  });

  final int id;
  final String cityName;
  final DateTime? scheduledTime;
  final int? stopIndex;

  String get formattedTime =>
      scheduledTime != null ? DateFormat('HH:mm').format(scheduledTime!) : '';

  factory TripStop.fromJson(Map<String, dynamic> json) => TripStop(
        id: json['id'] as int? ?? json['stopIndex'] as int? ?? 0,
        cityName: json['cityName'] as String? ??
            json['cityLabel'] as String? ?? // ← ajoute
            json['city'] as String? ??
            '',
        scheduledTime: json['scheduledTime'] != null
            ? DateTime.tryParse(json['scheduledTime'] as String)
            : json['plannedDepartureAt'] != null // ← ajoute
                ? DateTime.tryParse(json['plannedDepartureAt'] as String)
                : null,
        stopIndex: json['stopIndex'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cityName': cityName,
        if (scheduledTime != null)
          'scheduledTime': scheduledTime!.toIso8601String(),
        if (stopIndex != null) 'stopIndex': stopIndex,
      };
}
