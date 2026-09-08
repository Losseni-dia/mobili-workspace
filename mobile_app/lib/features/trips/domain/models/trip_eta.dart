/// Réponse de GET /trips/{id}/eta — voir backend TripEtaResponse.
/// `available == false` quand le prochain arrêt n'a pas de coordonnées
/// renseignées : jamais une estimation approximative dans ce cas, juste
/// "indisponible" (voir `_EtaBadge` dans `trip_detail_page.dart`).
class TripEta {
  const TripEta({
    required this.available,
    required this.destinationCity,
    this.durationSeconds,
    this.distanceMeters,
    this.provider,
  });

  final bool available;
  final String? destinationCity;
  final int? durationSeconds;
  final double? distanceMeters;
  final String? provider;

  int? get durationMinutes =>
      durationSeconds != null ? (durationSeconds! / 60).round() : null;

  factory TripEta.fromJson(Map<String, dynamic> json) => TripEta(
        available: json['available'] as bool? ?? false,
        destinationCity: json['destinationCity'] as String?,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
        provider: json['provider'] as String?,
      );
}
