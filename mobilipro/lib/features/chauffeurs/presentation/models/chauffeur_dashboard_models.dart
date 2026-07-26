import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../partner/presentation/pages/dashboard_partner_page.dart'
    show PartnerDashboardStats;

class ChauffeurTripItem {
  const ChauffeurTripItem({
    required this.id,
    required this.source,
    required this.departureCity,
    required this.arrivalCity,
    this.boardingPoint,
    required this.departureDateTime,
    required this.status,
    this.partnerName,
    this.stationName,
    this.vehiculePlateNumber,
    this.vehicleType,
  });

  final int id;
  final String source;
  final String departureCity;
  final String arrivalCity;
  final String? boardingPoint;
  final DateTime departureDateTime;
  final String status;
  final String? partnerName;
  final String? stationName;
  final String? vehiculePlateNumber;
  final String? vehicleType;

  String get route => '$departureCity → $arrivalCity';
  String get formattedDate =>
      DateFormat('dd/MM/yyyy HH:mm').format(departureDateTime);
  String get formattedDay =>
      DateFormat('EEEE dd MMM', 'fr_FR').format(departureDateTime);

  bool get isToday {
    final now = DateTime.now();
    return departureDateTime.year == now.year &&
        departureDateTime.month == now.month &&
        departureDateTime.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return departureDateTime.year == tomorrow.year &&
        departureDateTime.month == tomorrow.month &&
        departureDateTime.day == tomorrow.day;
  }

  bool get isInProgress => status == 'EN_COURS';
  bool get isUpcoming =>
      status == 'PROGRAMMÉ' || status == 'PLANIFIE' || status == 'ASSIGNED';
  bool get isCompleted =>
      status == 'TERMINÉ' || status == 'TERMINE' || status == 'COMPLETED';

  factory ChauffeurTripItem.fromJson(Map<String, dynamic> json) =>
      ChauffeurTripItem(
        id: (json['id'] as num).toInt(),
        source: json['source'] as String? ?? 'ASSIGNED',
        departureCity: json['departureCity'] as String? ?? '',
        arrivalCity: json['arrivalCity'] as String? ?? '',
        boardingPoint: json['boardingPoint'] as String?,
        departureDateTime:
            DateTime.tryParse(json['departureDateTime'] as String? ?? '') ??
            DateTime.now(),
        status: json['status'] as String? ?? '',
        partnerName: json['partnerName'] as String?,
        stationName: json['stationName'] as String?,
        vehiculePlateNumber: json['vehiculePlateNumber'] as String?,
        vehicleType: json['vehicleType'] as String?,
      );
}

class ChauffeurOverview {
  const ChauffeurOverview({required this.upcoming, required this.history});
  final List<ChauffeurTripItem> upcoming;
  final List<ChauffeurTripItem> history;

  factory ChauffeurOverview.fromJson(Map<String, dynamic> json) =>
      ChauffeurOverview(
        upcoming: (json['upcoming'] as List<dynamic>? ?? [])
            .map((e) => ChauffeurTripItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => ChauffeurTripItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

final chauffeurOverviewProvider = FutureProvider.autoDispose<ChauffeurOverview>(
  (ref) async {
    final dio = ApiClient.instance.dio;
    final res = await dio.get<Map<String, dynamic>>('/trips/chauffeur/mine');
    return ChauffeurOverview.fromJson(res.data!);
  },
);

/// Synthèse "gare/partenaire" pour le conducteur covoiturage : trajets,
/// réservations, revenus — scopée sur SES trajets (jamais le pool entier).
/// N'est watché/affiché que si `profile.isCovoiturageDriver`.
final covoiturageDashboardStatsProvider =
    FutureProvider.autoDispose<PartnerDashboardStats>((ref) async {
      final dio = ApiClient.instance.dio;
      final res = await dio.get<Map<String, dynamic>>(
        '/covoiturage/trips/dashboard/stats',
      );
      return PartnerDashboardStats.fromJson(res.data!);
    });
